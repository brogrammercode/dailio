import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_receipt_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/fees_repository.dart';
import '../models/fee_models.dart';

class MemberSubscriptionDetailPage extends StatefulWidget {
  final String memberId;
  final String? subscriptionId;

  const MemberSubscriptionDetailPage({
    super.key,
    required this.memberId,
    this.subscriptionId,
  });

  @override
  State<MemberSubscriptionDetailPage> createState() =>
      _MemberSubscriptionDetailPageState();
}

class _MemberSubscriptionDetailPageState
    extends State<MemberSubscriptionDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _subscription;
  List<PaymentRequestModel> _paymentRequests = [];
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharingReceipt = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apiClient = context.read<ApiClient>();
    if (widget.subscriptionId == null) {
      setState(() => _loading = false);
      return;
    }
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'No active branch selected.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await apiClient.dio
          .get('/branches/$branchId/subscriptions/${widget.subscriptionId}');
      if (!mounted) return;
      setState(() {
        _subscription = Map<String, dynamic>.from(response.data['data'] as Map);
        final requests = (_subscription?['payment_requests'] as List?) ?? [];
        _paymentRequests = requests
            .map((item) => PaymentRequestModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171717),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Dailio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          DailioOverflowMenu<String>(
            items: const [
              DailioMenuItem(
                value: 'refresh',
                label: 'Refresh',
                icon: Iconsax.refresh,
              ),
            ],
            onSelected: (_) => _load(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ShimmerLoader.detailPage(),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: const Color(0xFFD95B00),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [_buildContent()],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.cloud_cross, size: 34, color: Color(0xFFD95B00)),
            const SizedBox(height: 12),
            const Text(
              'Could not load this subscription',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Please try again.',
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
              textAlign: TextAlign.center,
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

  Widget _buildContent() {
    final data = _subscription;
    if (data == null) {
      return _emptyCard(
        icon: Iconsax.card_remove,
        title: 'No subscription found',
        message: 'This member does not have an active subscription yet.',
      );
    }

    final plan = (data['plan'] as Map?)?.cast<String, dynamic>();
    final member = (data['member'] as Map?)?.cast<String, dynamic>();
    final user = (member?['user'] as Map?)?.cast<String, dynamic>();
    final avatarUrl = user?['avatar_url']?.toString();
    final memberName = user?['name']?.toString() ?? 'Member';
    final memberRole = member?['role'] is Map
        ? ((member?['role'] as Map)['name']?.toString() ?? 'Member')
        : 'Member';
    final entries = (data['ledger_entries'] as List?)
            ?.map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final status = data['status']?.toString() ?? 'UNKNOWN';
    final start = _date(data['start_date']);
    final end = _date(data['end_date']);
    final amountMinor = (data['agreed_amount_minor'] as num?)?.toInt() ?? 0;
    final outstanding = entries.fold<int>(
      0,
      (sum, entry) =>
          sum + ((entry['amount_minor_unit'] as num?)?.toInt() ?? 0),
    );

    final planName = plan?['name']?.toString() ?? 'Subscription';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(avatarUrl, memberName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    memberRole,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _badge(_pretty(status), color: _statusColor(status)),
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
                  const Text(
                    'PLAN',
                    style: TextStyle(
                      color: Color(0xFF969696),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    planName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$start — $end',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Color(0xFF969696),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(amountMinor),
                  style: const TextStyle(
                    color: Color(0xFFD95B00),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 17),
          child: Divider(height: 1),
        ),
        Row(
          children: [
            Expanded(child: _summaryValue('Outstanding', _money(outstanding))),
            Expanded(
              child: _summaryValue(
                'Requests',
                '${_paymentRequests.length}',
                alignEnd: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('Payments'),
        const SizedBox(height: 8),
        _paymentSection(outstanding),
        const SizedBox(height: 24),
        _sectionTitle('Activity'),
        const SizedBox(height: 8),
        _ledgerTimeline(entries),
      ],
    );
  }

  Widget _paymentSection(int outstandingMinorUnit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_paymentRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Text(
                'No payment requests yet.',
                style: TextStyle(color: Color(0xFF777777), fontSize: 13),
              ),
            ),
          ..._paymentRequests.asMap().entries.map(
                (item) => _paymentRow(item.value, item.key == 0),
              ),
          if (outstandingMinorUnit > 0) ...[
            if (_paymentRequests.isNotEmpty) const Divider(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showPaymentRequestForm(outstandingMinorUnit),
                icon: const Icon(Iconsax.document_upload, size: 17),
                label: Text(
                  'Submit evidence · ${_money(outstandingMinorUnit)}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentRow(PaymentRequestModel request, bool first) {
    final hasReceipt = request.payment?.receipt != null;
    final status = request.status.toUpperCase();
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hasReceipt
                  ? const Color(0xFFE8F7EF)
                  : const Color(0xFFFFF2E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasReceipt ? Iconsax.receipt_text : Iconsax.money_time,
              size: 17,
              color: hasReceipt
                  ? const Color(0xFF198754)
                  : const Color(0xFFD95B00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.method} · ${_money(request.amountMinorUnit)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.reason == null || request.reason!.isEmpty
                      ? _pretty(status)
                      : '${_pretty(status)} · ${request.reason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (hasReceipt)
            IconButton(
              tooltip: 'View receipt',
              onPressed: () => _viewReceipt(request),
              icon: const Icon(Iconsax.receipt_text, size: 19),
              color: const Color(0xFFD95B00),
              visualDensity: VisualDensity.compact,
            )
          else
            _badge(_pretty(status), color: _statusColor(status)),
        ],
      ),
    );
  }

  Widget _ledgerTimeline(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return _emptyCard(
        icon: Iconsax.receipt_item,
        title: 'No ledger activity',
        message: 'Charges and payments will appear here as they are posted.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 5),
      decoration: _boxDecoration(),
      child: Column(
        children: entries.asMap().entries.map((item) {
          final entry = item.value;
          final amount = (entry['amount_minor_unit'] as num?)?.toInt() ?? 0;
          final description = entry['description']?.toString() ??
              entry['category']?.toString() ??
              'Ledger entry';
          final category = entry['category']?.toString();
          final isLast = item.key == entries.length - 1;
          return _timelineRow(
            title: description,
            subtitle: [
              if (category != null && category.isNotEmpty) _pretty(category),
              _date(entry['created_at']),
            ].join(' · '),
            amount: _money(amount),
            isLast: isLast,
          );
        }).toList(),
      ),
    );
  }

  Widget _timelineRow({
    required String title,
    required String subtitle,
    required String amount,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 25,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD95B00),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFF0D8C7),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    amount,
                    style: const TextStyle(
                      color: Color(0xFFD95B00),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFFD95B00)),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? avatarUrl, String name) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFFFE2CC),
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFD95B00),
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _badge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF171717),
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEAEAEA)),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.toUpperCase();
    if (normalized.contains('EXPIRED') ||
        normalized.contains('REJECT') ||
        normalized.contains('FAILED')) {
      return const Color(0xFFB3261E);
    }
    if (normalized.contains('PENDING') ||
        normalized.contains('REQUEST') ||
        normalized.contains('DRAFT')) {
      return const Color(0xFFD95B00);
    }
    return const Color(0xFF198754);
  }

  String _pretty(String value) {
    return value
        .toLowerCase()
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _viewReceipt(PaymentRequestModel request) async {
    final paymentId = request.payment?.id;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (paymentId == null || branchId == null) return;
    try {
      final data =
          await context.read<FeesRepository>().getReceipt(branchId, paymentId);
      if (!mounted) return;
      final receipt = (data['receipt'] as Map?)?.cast<String, dynamic>() ?? {};
      final payment = (data['payment'] as Map?)?.cast<String, dynamic>() ?? {};
      final preferences = context.read<PreferencesStorage>();
      final member =
          (_subscription?['member'] as Map?)?.cast<String, dynamic>();
      final user = (member?['user'] as Map?)?.cast<String, dynamic>();
      final plan = (_subscription?['plan'] as Map?)?.cast<String, dynamic>();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.brandDark,
        builder: (sheetContext) => DailioReceiptSheet(
          receiptKey: _receiptKey,
          organizationName: preferences.activeOrganizationName ?? 'Dailio',
          branchName: preferences.activeBranchName ?? 'Branch',
          receiptNumber: receipt['receipt_number']?.toString() ?? '',
          issuedAt: _dateTime(receipt['issued_at']),
          memberName: user?['name']?.toString() ?? 'Member',
          planName: plan?['name']?.toString(),
          method: payment['method']?.toString() ?? request.method,
          totalPaid: _money((payment['amount_minor_unit'] as num?)?.toInt() ??
              request.payment?.amountMinorUnit ??
              request.amountMinorUnit),
          onShare: _shareReceipt,
          onClose: () => Navigator.pop(sheetContext),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt unavailable: $error')),
      );
    }
  }

  // Kept temporarily so older deep links compiled against the previous
  // receipt layout remain source-compatible while the shared sheet is used.
  // ignore: unused_element
  Future<void> _legacyViewReceipt(PaymentRequestModel request) async {
    final paymentId = request.payment?.id;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (paymentId == null || branchId == null) return;
    try {
      final data =
          await context.read<FeesRepository>().getReceipt(branchId, paymentId);
      if (!mounted) return;
      final receipt = (data['receipt'] as Map?)?.cast<String, dynamic>() ?? {};
      final payment = (data['payment'] as Map?)?.cast<String, dynamic>() ?? {};
      final preferences = context.read<PreferencesStorage>();
      final member =
          (_subscription?['member'] as Map?)?.cast<String, dynamic>();
      final user = (member?['user'] as Map?)?.cast<String, dynamic>();
      final memberName = user?['name']?.toString() ?? 'Member';
      final plan = (_subscription?['plan'] as Map?)?.cast<String, dynamic>();
      final planName = plan?['name']?.toString() ?? 'Subscription';
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.brandDark,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                        'Official Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Iconsax.close_circle,
                          color: Colors.white70),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  key: _receiptKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ClipPath(
                      clipper: _ReceiptEdgeClipper(),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'Dailio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${preferences.activeOrganizationName ?? 'Dailio'} · ${preferences.activeBranchName ?? 'Branch'}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xFF777777), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Divider(height: 1),
                            ),
                            _receiptLine('RECEIPT NO',
                                receipt['receipt_number']?.toString()),
                            _receiptLine(
                                'DATE & TIME', _dateTime(receipt['issued_at'])),
                            const SizedBox(height: 5),
                            const Text(
                              'MEMBER & BUYER DETAILS',
                              style: TextStyle(
                                color: Color(0xFFD95B00),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            _receiptLine('Member', memberName),
                            _receiptLine('Plan', planName),
                            _receiptLine(
                                'Payment', payment['method']?.toString()),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            _receiptLine(
                              'TOTAL PAID',
                              _money((payment['amount_minor_unit'] as num?)
                                      ?.toInt() ??
                                  0),
                              emphasize: true,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFFF7600)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PAID · CONFIRMED',
                                  style: TextStyle(
                                    color: Color(0xFFD95B00),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharingReceipt ? null : _shareReceipt,
                        icon: _sharingReceipt
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Iconsax.share, size: 17),
                        label: const Text('Share receipt'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7600),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt unavailable: $error')),
      );
    }
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
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Receipt image could not be created');
      }
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'image/png',
            name: 'dailio-receipt.png',
          ),
        ],
        text: 'Dailio payment receipt',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share receipt: $error')),
      );
    } finally {
      if (mounted) setState(() => _sharingReceipt = false);
    }
  }

  Widget _receiptLine(String label, String? value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.isEmpty ? '—' : value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
                fontSize: emphasize ? 15 : 12,
                color: emphasize ? const Color(0xFFD95B00) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentRequestForm(int outstandingMinorUnit) async {
    final amountController = TextEditingController(
      text: (outstandingMinorUnit / 100).toStringAsFixed(2),
    );
    final referenceController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Iconsax.document_upload, color: Color(0xFFD95B00)),
            const SizedBox(width: 9),
            const Text('Submit evidence'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (INR)',
                prefixIcon: Icon(Iconsax.money_3, size: 18),
              ),
            ),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Reference / UPI ID',
                prefixIcon: Icon(Iconsax.receipt_text, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a reference or attach a receipt so staff can verify the request.',
              style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'amount': amountController.text,
              'reference': referenceController.text,
            }),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    amountController.dispose();
    referenceController.dispose();
    if (result == null || !mounted) return;
    final amount = double.tryParse(result['amount'] ?? '') ?? 0;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    final subscriptionId = widget.subscriptionId;
    if (branchId == null || subscriptionId == null || amount <= 0) return;
    try {
      final repository = context.read<FeesRepository>();
      final evidence = await _uploadEvidence(repository, branchId);
      final reference = (result['reference'] ?? '').trim();
      if (evidence == null && reference.isEmpty) {
        throw Exception('Attach a receipt or enter a payment reference');
      }
      await repository.createPaymentRequest(
        branchId,
        {
          'subscription_id': subscriptionId,
          'amount_minor_unit': (amount * 100).round(),
          'currency': 'INR',
          'method': 'UPI',
          if (reference.isNotEmpty) 'reference': reference,
          'evidence': [
            if (evidence != null)
              {
                'storage_key': evidence['storage_key'],
                'content_type': evidence['content_type'],
                'size_bytes': evidence['size_bytes'],
              },
          ],
        },
        idempotencyKey:
            'mobile-payment-$subscriptionId-${DateTime.now().toUtc().toIso8601String()}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request submitted for review')),
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit payment request: $error')),
      );
    }
  }

  Future<Map<String, dynamic>?> _uploadEvidence(
    FeesRepository repository,
    String branchId,
  ) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      throw Exception('Evidence file must be smaller than 20 MB');
    }
    final contentType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final signature = await repository.createEvidenceUploadSignature(
      branchId,
      picked.name,
      contentType,
    );
    final uploadUrl =
        'https://api.cloudinary.com/v1_1/${signature['cloud_name']}/auto/upload';
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: picked.name),
      'api_key': signature['api_key'],
      'timestamp': signature['timestamp'],
      'signature': signature['signature'],
      'folder': signature['folder'],
      'public_id': signature['public_id'],
      'type': signature['type'],
    });
    final uploadDio = Dio()..interceptors.add(LoggingInterceptor());
    final response = await uploadDio.post(
      uploadUrl,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    if (response.statusCode != 200) throw Exception('Evidence upload failed');
    final storageKey = signature['storage_key']?.toString();
    return storageKey == null
        ? null
        : {
            'storage_key': storageKey,
            'content_type': contentType,
            'size_bytes': sizeBytes,
          };
  }

  String _money(int minor) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
          .format(minor / 100);

  String _date(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null
        ? '—'
        : DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }

  String _dateTime(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null
        ? '—'
        : DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }
}

class _ReceiptEdgeClipper extends CustomClipper<Path> {
  const _ReceiptEdgeClipper();

  @override
  Path getClip(Size size) {
    const waveHeight = 6.0;
    const waveLength = 16.0;
    final path = Path()..moveTo(0, waveHeight);

    for (double x = 0; x <= size.width; x += waveLength) {
      final nextX = (x + waveLength).clamp(0, size.width).toDouble();
      path.quadraticBezierTo(
        x + waveLength / 2,
        x % (waveLength * 2) == 0 ? 0 : waveHeight * 2,
        nextX,
        waveHeight,
      );
    }

    path.lineTo(size.width, size.height - waveHeight);
    for (double x = size.width; x >= 0; x -= waveLength) {
      final nextX = (x - waveLength).clamp(0, size.width).toDouble();
      path.quadraticBezierTo(
        x - waveLength / 2,
        x % (waveLength * 2) == 0 ? size.height : size.height - waveHeight * 2,
        nextX,
        size.height - waveHeight,
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ReceiptEdgeClipper oldClipper) => false;
}
