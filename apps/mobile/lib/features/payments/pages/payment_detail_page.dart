import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/json_cache_store.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_receipt_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../fees/controllers/fees_repository.dart';
import '../../fees/models/fee_models.dart';
import '../../fees/models/financial_models.dart';
import '../../fees/pages/member_subscription_detail_page.dart';

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
        if (_canReview(request)) ...[
          const SizedBox(height: 22),
          _reviewSection(request),
        ],
        if (_canEdit(request)) ...[
          const SizedBox(height: 22),
          _editSection(request),
        ],
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
    if (request.evidence.isNotEmpty) {
      return _interactiveEvidenceSection(request);
    }
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

  Widget _interactiveEvidenceSection(PaymentRequestModel request) {
    return _section([
      for (var index = 0; index < request.evidence.length; index++)
        _evidenceRow(
          request,
          request.evidence[index],
          isLast: index == request.evidence.length - 1,
        ),
    ]);
  }

  Widget _evidenceRow(
    PaymentRequestModel request,
    PaymentEvidenceModel item, {
    required bool isLast,
  }) {
    final isPdf = item.contentType.toLowerCase().contains('pdf');
    return InkWell(
      onTap: () => _openEvidence(request, item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
        child: Row(
          children: [
            Icon(
              isPdf ? Iconsax.document_text : Iconsax.gallery,
              color: AppColors.brandAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPdf
                        ? 'Payment receipt document'
                        : 'Payment evidence image',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.sizeBytes == null ? '' : '${(item.sizeBytes! / 1024).ceil()} KB · '}Tap to ${isPdf ? 'open' : 'preview'} · ${_dateTime(item.createdAt)}',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Iconsax.arrow_right_3,
              color: Color(0xFF999999),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEvidence(
    PaymentRequestModel request,
    PaymentEvidenceModel evidence,
  ) async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) return;
    try {
      final result =
          await context.read<FeesRepository>().getEvidenceDownloadUrl(
                branchId,
                request.id,
                evidence.id,
              );
      final url = result['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Evidence link is unavailable');
      }
      if (evidence.contentType.toLowerCase().contains('pdf')) {
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) throw Exception('The document could not be opened');
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 320,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brandAccent,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                      height: 320,
                      child: Center(
                        child: Text(
                          'Evidence preview unavailable',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Iconsax.close_circle, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open evidence: $error')),
      );
    }
  }

  bool _canReview(PaymentRequestModel request) {
    final canReview = context.read<PreferencesStorage>().canReviewPayments;
    return canReview &&
        (request.status == 'REQUESTED' ||
            request.status == 'NEEDS_INFORMATION');
  }

  bool _canEdit(PaymentRequestModel request) {
    final currentUserId = context.read<JsonCacheStore>().userId;
    return currentUserId != null &&
        currentUserId == request.memberUserId &&
        request.subscriptionId != null &&
        (request.status == 'REQUESTED' ||
            request.status == 'NEEDS_INFORMATION');
  }

  Widget _editSection(PaymentRequestModel request) {
    return _section([
      _sectionTitle('Your submission'),
      const SizedBox(height: 5),
      const Text(
        'Only the member who submitted this request can update its details or evidence.',
        style: TextStyle(color: Color(0xFF777777), fontSize: 11),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberSubscriptionDetailPage(
                  memberId: request.memberId ?? '',
                  subscriptionId: request.subscriptionId,
                ),
              ),
            );
          },
          icon: const Icon(Iconsax.edit_2, size: 17),
          label: const Text('Edit submission'),
        ),
      ),
    ]);
  }

  Widget _reviewSection(PaymentRequestModel request) {
    return _section([
      _sectionTitle('Review payment'),
      const SizedBox(height: 5),
      const Text(
        'Review the member-submitted payment evidence and choose the next state.',
        style: TextStyle(color: Color(0xFF777777), fontSize: 11),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _review(request.id, 'approve'),
            icon: const Icon(Iconsax.tick_circle, size: 16),
            label: const Text('Approve'),
          ),
          OutlinedButton.icon(
            onPressed: () => _review(request.id, 'needs_information'),
            icon: const Icon(Iconsax.info_circle, size: 16),
            label: const Text('Need info'),
          ),
          TextButton.icon(
            onPressed: () => _review(request.id, 'reject'),
            icon: const Icon(Iconsax.close_circle, size: 16),
            label: const Text('Reject'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ],
      ),
    ]);
  }

  Future<void> _review(String requestId, String action) async {
    final preferences = context.read<PreferencesStorage>();
    final repository = context.read<FeesRepository>();
    String? reason;
    if (action == 'approve') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Approve payment?',
        message:
            'This will post the payment to the member ledger and generate the official receipt.',
        confirmLabel: 'Approve',
        icon: Iconsax.tick_circle,
      );
      if (!confirmed) return;
    } else {
      reason = await showReasonDialog(
        context,
        title: action == 'reject' ? 'Reject payment' : 'Request information',
        message: action == 'reject'
            ? 'Add a reason for the member and payment history.'
            : 'Explain what the member needs to provide.',
        confirmLabel: 'Submit',
        hintText: 'Explain what is needed',
        isDestructive: action == 'reject',
        icon: action == 'reject' ? Iconsax.close_circle : Iconsax.message_text,
      );
      if (reason == null) return;
    }

    final branchId = preferences.activeBranchId;
    if (branchId == null || !mounted) return;
    try {
      await repository.reviewPaymentRequest(
        branchId,
        requestId,
        action,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment ${action.replaceAll('_', ' ')}.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update payment: $error')),
      );
    }
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
