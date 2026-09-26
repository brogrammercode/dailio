import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/router/route_names.dart';
import '../controllers/branch_repository.dart';
import '../../attendance/pages/gate_attendance_page.dart';

String? extractDailioInviteToken(BarcodeCapture? capture) {
  for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
    final rawValue = barcode.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) continue;

    final uri = Uri.tryParse(rawValue);
    if (uri?.scheme.toLowerCase() != 'dailio' ||
        uri?.host.toLowerCase() != 'invite') {
      continue;
    }

    final token = uri?.queryParameters['token']?.trim();
    if (token != null && token.isNotEmpty) return token;
  }
  return null;
}

String qrInviteFlowState(Map<String, dynamic> invite) {
  if (invite['purpose'] == 'PLAN_PURCHASE') return 'PLAN_PURCHASE';
  switch (invite['joinability']?.toString()) {
    case 'ALREADY_MEMBER':
      switch (invite['attendance_action']?.toString()) {
        case 'CLOCK_OUT':
          return 'ACTIVE_CLOCK_OUT';
        case 'CLOCK_IN':
          return 'ACTIVE_CLOCK_IN';
        case 'ATTENDANCE_DISABLED':
          return 'ATTENDANCE_DISABLED';
        default:
          return 'UNKNOWN';
      }
    case 'ALREADY_PENDING':
      return 'PENDING';
    case 'MEMBERSHIP_INACTIVE':
      return 'INACTIVE';
    case 'JOINABLE':
      return 'JOINABLE';
    default:
      return 'UNKNOWN';
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  DateTime? _lastInvalidScanNotice;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final token = extractDailioInviteToken(capture);
    if (token != null) {
      _processInviteToken(token);
      return;
    }

    final hasRawBarcode = capture.barcodes.any(
      (barcode) => barcode.rawValue?.trim().isNotEmpty == true,
    );
    if (hasRawBarcode) _showInvalidScanNotice();
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      await _controller.stop();
      final capture = await _controller.analyzeImage(image.path);
      final token = extractDailioInviteToken(capture);

      if (token == null) {
        _showMessage('No valid Dailio invite QR was found in that image.');
        return;
      }

      await _resolveAndContinue(token, fromGallery: true);
    } catch (_) {
      if (mounted) {
        _showMessage(
            'We could not read that image. Please try another QR image.');
      }
    } finally {
      await _resumeCamera();
    }
  }

  Future<void> _processInviteToken(String token) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      await _controller.stop();
      await _resolveAndContinue(token);
    } catch (_) {
      if (mounted) {
        _showMessage('This QR code is invalid, revoked, or unavailable.');
      }
    } finally {
      await _resumeCamera();
    }
  }

  Future<void> _resolveAndContinue(String token,
      {bool fromGallery = false}) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw Exception(
          'An internet connection is required to validate this QR.');
    }
    if (!mounted) return;
    final repository = context.read<BranchRepository>();
    final invite = await repository.resolveInvite(token);

    if (!mounted) return;

    final flowState = qrInviteFlowState(invite);
    if (flowState == 'PLAN_PURCHASE') {
      context.pushReplacement(
        AppRoutes.subscriptionPurchase,
        extra: {...invite, 'token': token},
      );
      return;
    }

    if (flowState == 'ACTIVE_CLOCK_IN' || flowState == 'ACTIVE_CLOCK_OUT') {
      final branch = (invite['branch'] as Map?)?.cast<String, dynamic>() ?? {};
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GateAttendancePage(
          token: token,
          invite: {
            ...invite,
            'branch': branch,
            'scan_from_gallery': fromGallery,
          },
        ),
      ));
      return;
    }
    if (flowState == 'PENDING') {
      context.go(AppRoutes.pendingJoin);
      return;
    }
    if (flowState == 'INACTIVE') {
      _showMessage(
          'This branch membership is inactive. Contact the branch owner before trying again.');
      return;
    }
    if (flowState == 'ATTENDANCE_DISABLED') {
      _showMessage(
          'Attendance punching is not required for your current policy at this branch.');
      return;
    }
    if (flowState == 'UNKNOWN') {
      _showMessage('This invite is unavailable or cannot be used right now.');
      return;
    }

    final branch = (invite['branch'] as Map?)?.cast<String, dynamic>() ?? {};
    final organization =
        (invite['organization'] as Map?)?.cast<String, dynamic>() ?? {};
    final organizationName = organization['name'] ?? 'this organization';
    final branchName = branch['name'] ?? 'this branch';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm fast join'),
        content: Text(
          'Send a membership request to $organizationName · $branchName?\n\n'
          'The owner will review your request before you become an active member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await repository.submitInviteJoinRequest(
      token,
      idempotencyKey:
          'mobile-join-${DateTime.now().toUtc().millisecondsSinceEpoch}',
    );

    if (!mounted) return;
    _showMessage('Request submitted. Waiting for approval.');
    context.go(AppRoutes.pendingJoin);
  }

  Future<void> _resumeCamera() async {
    if (!mounted) return;

    setState(() => _isProcessing = false);
    try {
      await _controller.start();
    } catch (_) {
      // The page may be leaving while the camera is being resumed.
    }
  }

  void _showInvalidScanNotice() {
    final now = DateTime.now();
    final lastNotice = _lastInvalidScanNotice;
    if (lastNotice != null && now.difference(lastNotice).inSeconds < 3) {
      return;
    }
    _lastInvalidScanNotice = now;
    _showMessage('That is not a Dailio invite QR.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan to join'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            onPressed: _isProcessing ? null : _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _isProcessing ? null : _controller.switchCamera,
            icon: const Icon(Icons.flip_camera_ios_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            CustomPaint(
              painter: ScannerOverlayPainter(),
              child: const SizedBox.expand(),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      'Dailio fast join',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _ScannerActions(
                isProcessing: _isProcessing,
                onPickFromGallery: _pickFromGallery,
              ),
            ),
            if (_isProcessing)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.56),
                  child: const Center(
                    child: _ScannerProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ScannerActions extends StatelessWidget {
  const _ScannerActions({
    required this.isProcessing,
    required this.onPickFromGallery,
  });

  final bool isProcessing;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Scan a Dailio QR code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use your camera or select a saved QR image.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isProcessing ? null : onPickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerProgressIndicator extends StatelessWidget {
  const _ScannerProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFFFF8A00),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Checking invite…',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final area = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 24),
      width: 250,
      height: 250,
    );
    path.addRRect(RRect.fromRectAndRadius(area, const Radius.circular(18)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final cornerPaint = Paint()
      ..color = const Color(0xFFFF8A00)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    const length = 30.0;
    canvas.drawLine(
      area.topLeft,
      area.topLeft + const Offset(length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      area.topLeft,
      area.topLeft + const Offset(0, length),
      cornerPaint,
    );
    canvas.drawLine(
      area.topRight,
      area.topRight + const Offset(-length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      area.topRight,
      area.topRight + const Offset(0, length),
      cornerPaint,
    );
    canvas.drawLine(
      area.bottomLeft,
      area.bottomLeft + const Offset(length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      area.bottomLeft,
      area.bottomLeft + const Offset(0, -length),
      cornerPaint,
    );
    canvas.drawLine(
      area.bottomRight,
      area.bottomRight + const Offset(-length, 0),
      cornerPaint,
    );
    canvas.drawLine(
      area.bottomRight,
      area.bottomRight + const Offset(0, -length),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
