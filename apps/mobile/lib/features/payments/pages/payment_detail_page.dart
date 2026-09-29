import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_receipt_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../fees/controllers/fees_repository.dart';
import '../../fees/models/fee_models.dart';
import '../../fees/models/financial_models.dart';

class PaymentDetailPage extends StatefulWidget {
  final String requestId;

  const PaymentDetailPage({super.key, required this.requestId});

  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage> {
  bool _loading = true;
  String? _error;
  PaymentRequestModel? _request;
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharingReceipt = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'Select an active branch to view this payment.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context
          .read<FeesRepository>()
          .getPaymentRequest(branchId, widget.requestId);
      final data = (response['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) throw Exception('Payment details are unavailable');
      if (!mounted) return;
      setState(() {
        _request = PaymentRequestModel.fromJson(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh payment',
          ),
        ],
        onMenuSelected: (_) => _load(),
      ),
      body: _loading
          ? Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ShimmerLoader.detailPage(),
            )
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  color: AppColors.brandAccent,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [_content(_request!)],
                  ),
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.cloud_cross,
                size: 34, color: AppColors.brandAccent),
            const SizedBox(height: 12),
            const Text(
              'Could not load this payment',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Iconsax.refresh, size: 17),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(PaymentRequestModel request) {
    final name = request.memberName ?? 'Member';
    final payment = request.payment;
    final receipt = payment?.receipt;
    final isDeduct = request.signedAmountMinorUnit < 0;
    final amountColor = isDeduct ? AppColors.error : AppColors.brandDark;
    final amount = request.signedAmountMinorUnit.abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(request),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    request.memberRoleName ?? request.planName ?? 'Member',
                    style:
                        const TextStyle(color: Color(0xFF777777), fontSize: 12),
                  ),
                ],
              ),
            ),
            _badge(_pretty(request.status), _statusColor(request.status)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PAYMENT',
                      style: TextStyle(
                          color: Color(0xFF969696),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8)),
                  const SizedBox(height: 5),
                  Text(
                    isDeduct ? 'Deduct' : 'Credit',
                    style: TextStyle(
                        color: amountColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.method} · ${_dateTime(request.createdAt)}',
                    style:
                        const TextStyle(color: Color(0xFF777777), fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '${isDeduct ? '-' : '+'}${_money(amount, request.currency)}',
              style: TextStyle(
                  color: amountColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 17),
          child: Divider(height: 1),
        ),
        _sectionTitle('Payment information'),
        const SizedBox(height: 8),
        _section([
          _detail('Status', _pretty(request.status)),
          _detail('Method', request.method),
          _detail('Reference', request.reference ?? 'Not provided'),
          if (request.note != null && request.note!.isNotEmpty)
            _detail('Note', request.note!),
          _detail('Submitted', _dateTime(request.createdAt)),
          if (payment != null) _detail('Posted', _dateTime(payment.postedAt)),
          if (request.reason != null && request.reason!.isNotEmpty)
            _detail('Reviewer note', request.reason!),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('Receipt'),
        const SizedBox(height: 8),
        _receiptRow(request, receipt),
        const SizedBox(height: 22),
        _sectionTitle('Evidence'),
        const SizedBox(height: 8),
        _evidenceSection(request),
        if (request.planName != null) ...[
          const SizedBox(height: 22),
          _sectionTitle('Subscription'),
          const SizedBox(height: 8),
          _section([
            _detail('Plan', request.planName!),
            const Text(
              'This payment is linked to the subscription plan shown above.',
              style: TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _receiptRow(PaymentRequestModel request, ReceiptModel? receipt) {
    if (receipt == null) {
      return _section([
        const Row(
          children: [
            Icon(Iconsax.receipt_minus, color: Color(0xFF999999), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Receipt will appear after this payment is approved.',
                style: TextStyle(color: Color(0xFF777777), fontSize: 12),
              ),
            ),
          ],
        ),
      ]);
    }
    return _section([
      Row(
        children: [
          const Icon(Iconsax.receipt_text,
              color: AppColors.brandAccent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receipt.receiptNumber,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  'Issued ${_dateTime(receipt.issuedAt)} · ${request.payment?.status ?? 'PAID'}',
                  style:
                      const TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View receipt',
            onPressed: () => _showReceipt(request),
            icon: const Icon(Iconsax.arrow_right_3, size: 19),
            color: AppColors.brandAccent,
          ),
        ],
      ),
    ]);
  }

  Widget _evidenceSection(PaymentRequestModel request) {
    if (request.evidence.isEmpty) {
      return _section([
        const Row(
          children: [
            Icon(Iconsax.document_text, color: Color(0xFF999999), size: 20),
            SizedBox(width: 10),
            Text('No evidence attached.',
                style: TextStyle(color: Color(0xFF777777), fontSize: 12)),
          ],
        ),
      ]);
    }
    return _section([
      ...request.evidence.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Iconsax.document_download,
                  color: AppColors.brandAccent, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.contentType,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '${item.sizeBytes == null ? '' : '${(item.sizeBytes! / 1024).ceil()} KB · '}${_dateTime(item.createdAt)}',
                      style: const TextStyle(
                          color: Color(0xFF777777), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _section(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style:
                      const TextStyle(color: Color(0xFF777777), fontSize: 11)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _avatar(PaymentRequestModel request) {
    final image = request.memberAvatarUrl;
    final name = request.memberName ?? 'Member';
    final child = CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFFFE2CC),
      backgroundImage:
          image == null || image.isEmpty ? null : NetworkImage(image),
      child: image == null || image.isEmpty
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.brandAccent, fontWeight: FontWeight.w800))
          : null,
    );
    if (request.memberId == null) return child;
    return GestureDetector(
      onTap: () => showDailioMemberProfileSheet(
        context,
        DailioMemberPreview(
          memberId: request.memberId!,
          name: name,
          role: request.memberRoleName ?? 'Member',
          status: request.status,
          avatarUrl: request.memberAvatarUrl,
          subscriptionLabel: request.planName,
        ),
      ),
      child: child,
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(7)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Future<void> _showReceipt(PaymentRequestModel request) async {
    final receipt = request.payment?.receipt;
    if (receipt == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.brandDark,
      builder: (sheetContext) => DailioReceiptSheet(
        receiptKey: _receiptKey,
        organizationName:
            context.read<PreferencesStorage>().activeOrganizationName ??
                'Dailio',
        branchName:
            context.read<PreferencesStorage>().activeBranchName ?? 'Branch',
        receiptNumber: receipt.receiptNumber,
        issuedAt: _dateTime(receipt.issuedAt),
        memberName: request.memberName ?? 'Member',
        method: request.payment?.method ?? request.method,
        totalPaid: _money(
          request.payment?.amountMinorUnit ?? request.amountMinorUnit,
          request.currency,
        ),
        onShare: _shareReceipt,
        onClose: () => Navigator.pop(sheetContext),
      ),
    );
  }

  Future<void> _shareReceipt() async {
    if (_sharingReceipt) return;
    setState(() => _sharingReceipt = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _receiptKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('Receipt preview is not ready');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Receipt image could not be created');
      }
      await Share.shareXFiles(
        [
          XFile.fromData(Uint8List.fromList(bytes),
              mimeType: 'image/png', name: 'dailio-receipt.png')
        ],
        text: 'Dailio payment receipt',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share receipt: $error')));
      }
    } finally {
      if (mounted) setState(() => _sharingReceipt = false);
    }
  }

  Color _statusColor(String status) => switch (status) {
        'APPROVED' => AppColors.brandDark,
        'REJECTED' => AppColors.error,
        'NEEDS_INFORMATION' => AppColors.brandAccent,
        'CANCELLED' => const Color(0xFF6B6B6B),
        _ => AppColors.brandAccent,
      };

  String _pretty(String value) => value
      .toLowerCase()
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _money(int minor, String currency) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '$currency ',
        decimalDigits: 2,
      ).format(minor / 100);

  String _dateTime(DateTime? value) => value == null
      ? 'Not available'
      : DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
}
