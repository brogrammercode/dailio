import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/router/route_names.dart';
import '../controllers/branch_repository.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('dailio://join')) {
        setState(() => _isProcessing = true);
        controller.stop();

        final uri = Uri.parse(rawValue);
        final orgId = uri.queryParameters['orgId'];
        final branchId = uri.queryParameters['branchId'];

        if (orgId != null && branchId != null) {
          _fetchAndNavigate(orgId, branchId);
          return;
        }

        // Invalid QR
        setState(() => _isProcessing = false);
        controller.start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code. Please try another.')),
        );
      }
    }
  }

  Future<void> _fetchAndNavigate(String orgId, String branchId) async {
    try {
      final repo = context.read<BranchRepository>();
      final branches = await repo.discoverBranchesByOrg(orgId);
      final match = branches.where((b) => b.id == branchId).toList();

      if (!mounted) return;

      if (match.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Branch not found. Please check the QR code.')),
        );
        setState(() => _isProcessing = false);
        controller.start();
        return;
      }

      // Navigate to org detail with full BranchDiscoveryModel
      final orgBranches = branches.isNotEmpty ? branches : match;
      context.pushReplacement(
        AppRoutes.orgDetail.replaceFirst(':orgId', orgId),
        extra: orgBranches,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading branch: ${e.toString()}')),
      );
      setState(() => _isProcessing = false);
      controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR to Join'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => controller.toggleTorch(),
            icon: const Icon(Iconsax.flash),
          ),
          IconButton(
            onPressed: () => controller.switchCamera(),
            icon: const Icon(Iconsax.camera),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // Scanner Overlay overlay
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Align the QR code within the frame to scan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final scanAreaSize = 250.0;
    final scanAreaRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    path.addRRect(
        RRect.fromRectAndRadius(scanAreaRect, const Radius.circular(16)));
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corners
    final cornerPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final length = 30.0;

    // Top Left
    canvas.drawLine(scanAreaRect.topLeft,
        scanAreaRect.topLeft + Offset(length, 0), cornerPaint);
    canvas.drawLine(scanAreaRect.topLeft,
        scanAreaRect.topLeft + Offset(0, length), cornerPaint);

    // Top Right
    canvas.drawLine(scanAreaRect.topRight,
        scanAreaRect.topRight + Offset(-length, 0), cornerPaint);
    canvas.drawLine(scanAreaRect.topRight,
        scanAreaRect.topRight + Offset(0, length), cornerPaint);

    // Bottom Left
    canvas.drawLine(scanAreaRect.bottomLeft,
        scanAreaRect.bottomLeft + Offset(length, 0), cornerPaint);
    canvas.drawLine(scanAreaRect.bottomLeft,
        scanAreaRect.bottomLeft + Offset(0, -length), cornerPaint);

    // Bottom Right
    canvas.drawLine(scanAreaRect.bottomRight,
        scanAreaRect.bottomRight + Offset(-length, 0), cornerPaint);
    canvas.drawLine(scanAreaRect.bottomRight,
        scanAreaRect.bottomRight + Offset(0, -length), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
