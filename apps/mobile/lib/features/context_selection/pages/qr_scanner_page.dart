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
  final MobileScannerController controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      final uri = raw == null ? null : Uri.tryParse(raw);
      final token = uri?.scheme == 'dailio' && uri?.host == 'invite'
          ? uri?.queryParameters['token']
          : null;
      if (token == null || token.trim().isEmpty) continue;
      setState(() => _isProcessing = true);
      controller.stop();
      _resolveAndContinue(token.trim());
      return;
    }
  }

  Future<void> _resolveAndContinue(String token) async {
    try {
      final repository = context.read<BranchRepository>();
      final invite = await repository.resolveInvite(token);
      if (!mounted) return;
      if (invite['purpose'] == 'PLAN_PURCHASE') {
        context.pushReplacement(AppRoutes.subscriptionPurchase,
            extra: {...invite, 'token': token});
        return;
      }
      final joinability = invite['joinability']?.toString();
      if (joinability == 'ALREADY_MEMBER') {
        _showMessage('You are already an active member of this branch.');
      } else if (joinability == 'ALREADY_PENDING') {
        context.go(AppRoutes.pendingJoin);
        return;
      } else {
        final branch =
            (invite['branch'] as Map?)?.cast<String, dynamic>() ?? {};
        final organization =
            (invite['organization'] as Map?)?.cast<String, dynamic>() ?? {};
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm fast join'),
            content: Text(
                'Send a membership request to ${organization['name'] ?? 'this organization'} • ${branch['name'] ?? 'this branch'}?\n\nThe owner will review your request before you become active.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Send request')),
            ],
          ),
        );
        if (confirmed == true) {
          await repository.submitInviteJoinRequest(token,
              idempotencyKey:
                  'mobile-join-${DateTime.now().toUtc().millisecondsSinceEpoch}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Request submitted. Waiting for approval.')));
            context.go(AppRoutes.pendingJoin);
            return;
          }
        }
      }
    } catch (_) {
      if (mounted) {
        _showMessage('This QR code is invalid, expired, or unavailable.');
      }
    }
    if (mounted) {
      setState(() => _isProcessing = false);
      controller.start();
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Scan and Fast Join'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
                onPressed: controller.toggleTorch,
                icon: const Icon(Iconsax.flash)),
            IconButton(
                onPressed: controller.switchCamera,
                icon: const Icon(Iconsax.camera)),
          ],
        ),
        body: Stack(children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          CustomPaint(
              painter: ScannerOverlayPainter(), child: const SizedBox.expand()),
          const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text('Align a Dailio invite QR inside the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14))),
        ]),
      );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final area = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 250,
        height: 250);
    path.addRRect(RRect.fromRectAndRadius(area, const Radius.circular(16)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
    final cornerPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const length = 30.0;
    canvas.drawLine(
        area.topLeft, area.topLeft + const Offset(length, 0), cornerPaint);
    canvas.drawLine(
        area.topLeft, area.topLeft + const Offset(0, length), cornerPaint);
    canvas.drawLine(
        area.topRight, area.topRight + const Offset(-length, 0), cornerPaint);
    canvas.drawLine(
        area.topRight, area.topRight + const Offset(0, length), cornerPaint);
    canvas.drawLine(area.bottomLeft, area.bottomLeft + const Offset(length, 0),
        cornerPaint);
    canvas.drawLine(area.bottomLeft, area.bottomLeft + const Offset(0, -length),
        cornerPaint);
    canvas.drawLine(area.bottomRight,
        area.bottomRight + const Offset(-length, 0), cornerPaint);
    canvas.drawLine(area.bottomRight,
        area.bottomRight + const Offset(0, -length), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
