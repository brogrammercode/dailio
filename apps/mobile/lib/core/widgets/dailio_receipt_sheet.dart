import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';

/// The single receipt presentation used by payment and subscription details.
///
/// The paper is deliberately a separate repaint boundary so callers can share
/// the exact receipt image without capturing the surrounding bottom sheet.
class DailioReceiptSheet extends StatefulWidget {
  final GlobalKey receiptKey;
  final String organizationName;
  final String branchName;
  final String receiptNumber;
  final String issuedAt;
  final String memberName;
  final String? planName;
  final String method;
  final String totalPaid;
  final Future<void> Function() onShare;
  final VoidCallback onClose;

  const DailioReceiptSheet({
    super.key,
    required this.receiptKey,
    required this.organizationName,
    required this.branchName,
    required this.receiptNumber,
    required this.issuedAt,
    required this.memberName,
    this.planName,
    required this.method,
    required this.totalPaid,
    required this.onShare,
    required this.onClose,
  });

  @override
  State<DailioReceiptSheet> createState() => _DailioReceiptSheetState();
}

class _DailioReceiptSheetState extends State<DailioReceiptSheet> {
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await widget.onShare();
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.receipt_text,
                      color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Official receipt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Close receipt',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Iconsax.close_circle,
                        color: Colors.white70, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: RepaintBoundary(
                    key: widget.receiptKey,
                    child: _ReceiptPaper(
                      organizationName: widget.organizationName,
                      branchName: widget.branchName,
                      receiptNumber: widget.receiptNumber,
                      issuedAt: widget.issuedAt,
                      memberName: widget.memberName,
                      planName: widget.planName,
                      method: widget.method,
                      totalPaid: widget.totalPaid,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSharing ? null : _share,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Iconsax.share, size: 17),
                  label:
                      Text(_isSharing ? 'Preparing receipt…' : 'Share receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptPaper extends StatelessWidget {
  final String organizationName;
  final String branchName;
  final String receiptNumber;
  final String issuedAt;
  final String memberName;
  final String? planName;
  final String method;
  final String totalPaid;

  const _ReceiptPaper({
    required this.organizationName,
    required this.branchName,
    required this.receiptNumber,
    required this.issuedAt,
    required this.memberName,
    required this.planName,
    required this.method,
    required this.totalPaid,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _ReceiptEdgeClipper(),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Text('Dailio',
                      style: TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text(
                    '$organizationName · $branchName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFF7E7E7E), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE7E7E7)),
            const SizedBox(height: 14),
            _line('Receipt no', receiptNumber),
            _line('Date & time', issuedAt),
            const SizedBox(height: 12),
            const Text(
              'PAYMENT DETAILS',
              style: TextStyle(
                color: AppColors.brandAccent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            _line('Member', memberName),
            if (planName != null && planName!.isNotEmpty)
              _line('Plan', planName!),
            _line('Method', method),
            const SizedBox(height: 7),
            const Divider(height: 1, color: Color(0xFFE7E7E7)),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text('TOTAL PAID',
                      style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                Text(totalPaid,
                    style: const TextStyle(
                        color: AppColors.brandAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4EA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFD4B0)),
                ),
                child: const Text(
                  'PAID · CONFIRMED',
                  style: TextStyle(
                      color: AppColors.brandAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF858585),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ReceiptEdgeClipper extends CustomClipper<Path> {
  const _ReceiptEdgeClipper();

  @override
  Path getClip(Size size) {
    const edgeHeight = 7.0;
    const toothWidth = 18.0;
    final path = Path()..moveTo(0, edgeHeight);
    for (double x = 0; x <= size.width; x += toothWidth) {
      final end = (x + toothWidth).clamp(0, size.width).toDouble();
      path.quadraticBezierTo(
        x + toothWidth / 2,
        x % (toothWidth * 2) == 0 ? 0 : edgeHeight * 2,
        end,
        edgeHeight,
      );
    }
    path.lineTo(size.width, size.height - edgeHeight);
    for (double x = size.width; x >= 0; x -= toothWidth) {
      final end = (x - toothWidth).clamp(0, size.width).toDouble();
      path.quadraticBezierTo(
        x - toothWidth / 2,
        x % (toothWidth * 2) == 0 ? size.height : size.height - edgeHeight * 2,
        end,
        size.height - edgeHeight,
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ReceiptEdgeClipper oldClipper) => false;
}
