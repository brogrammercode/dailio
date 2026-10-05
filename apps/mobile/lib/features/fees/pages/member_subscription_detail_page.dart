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

import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/storage/json_cache_store.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_receipt_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/fees_repository.dart';
import '../models/fee_models.dart';
import '../../payments/pages/payment_detail_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  bool _waiversOpen = false;
  bool _waiversLoading = false;
  String? _waiversError;
  List<Map<String, dynamic>> _waivers = [];
  int _waiverPage = 1;
  int _waiverTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      final response = await context.read<FeesRepository>().getSubscription(
        branchId,
        widget.subscriptionId!,
        onFresh: (freshData) {
          if (mounted) _applySubscription(freshData);
        },
      );
      if (!mounted) return;
      _applySubscription(response);
      setState(() => _loading = false);
      if (_waiversOpen) await _loadWaivers();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applySubscription(Map<String, dynamic> response) {
    final raw = response['data'];
    final subscription = raw is Map ? Map<String, dynamic>.from(raw) : response;
    final requests = (subscription['payment_requests'] as List?) ?? [];
    final parsedRequests = requests
        .whereType<Map>()
        .map((item) =>
            PaymentRequestModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (!mounted) return;
    setState(() {
      _subscription = subscription;
      _paymentRequests = parsedRequests;
    });
  }

  bool get _isOwnSubscription {
    final member = (_subscription?['member'] as Map?)?.cast<String, dynamic>();
    final memberUserId = member?['user_id']?.toString();
    final currentUserId = context.read<JsonCacheStore>().userId;
    return memberUserId != null &&
        currentUserId != null &&
        memberUserId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            label: 'Refresh',
            icon: Iconsax.refresh,
          ),
        ],
        onMenuSelected: (_) => _load(),
      ),
      body: _loading
          ? Padding(
              padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 0),
              child: ShimmerLoader.detailPage(),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: const Color(0xFFD95B00),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 32.r),
                    children: [_buildContent()],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.cloud_cross, size: 34.r, color: Color(0xFFD95B00)),
            SizedBox(height: 12.r),
            Text(
              'Could not load this subscription',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.r),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.r),
            Text(
              _error ?? 'Please try again.',
              style: TextStyle(color: Color(0xFF777777), fontSize: 12.r),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.r),
            OutlinedButton.icon(
              onPressed: _load,
              icon: Icon(Iconsax.refresh, size: 17.r),
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
    final paid = entries
        .where((entry) => entry['category'] == 'PAYMENT')
        .fold<int>(
            0,
            (sum, entry) =>
                sum - ((entry['amount_minor_unit'] as num?)?.toInt() ?? 0));
    final waived = entries
        .where((entry) => entry['category'] == 'SETTLEMENT_WAIVER')
        .fold<int>(
            0,
            (sum, entry) =>
                sum - ((entry['amount_minor_unit'] as num?)?.toInt() ?? 0));
    final waiverLedgerIds = entries
        .where((entry) => entry['category'] == 'SETTLEMENT_WAIVER')
        .map((entry) => entry['id']?.toString())
        .toSet();
    final reversedWaivers = entries
        .where((entry) =>
            entry['category'] == 'VOID_REVERSAL' &&
            waiverLedgerIds.contains(entry['reversed_by_id']?.toString()))
        .fold<int>(
            0,
            (sum, entry) =>
                sum + ((entry['amount_minor_unit'] as num?)?.toInt() ?? 0));
    final charged = entries
        .where((entry) => const {
              'SUBSCRIPTION_CHARGE',
              'JOINING_FEE',
              'FINE',
              'MANUAL_DEBIT'
            }.contains(entry['category']))
        .fold<int>(
            0,
            (sum, entry) =>
                sum + ((entry['amount_minor_unit'] as num?)?.toInt() ?? 0));

    final planName = plan?['name']?.toString() ?? 'Subscription';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(avatarUrl, memberName, status: status, role: memberRole),
            SizedBox(width: 10.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17.r,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF171717),
                    ),
                  ),
                  SizedBox(height: 3.r),
                  Text(
                    memberRole,
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12.r,
                    ),
                  ),
                ],
              ),
            ),
            _badge(_pretty(status), color: _statusColor(status)),
          ],
        ),
        SizedBox(height: 24.r),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAN',
                    style: TextStyle(
                      color: Color(0xFF969696),
                      fontSize: 10.r,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8.r,
                    ),
                  ),
                  SizedBox(height: 5.r),
                  Text(
                    planName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18.r,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.r),
                  Text(
                    '$start — $end',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12.r,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.r),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Color(0xFF969696),
                    fontSize: 10.r,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8.r,
                  ),
                ),
                SizedBox(height: 5.r),
                Text(
                  _money(amountMinor),
                  style: TextStyle(
                    color: Color(0xFFD95B00),
                    fontSize: 17.r,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 17.r),
          child: Divider(height: 1.r),
        ),
        Row(
          children: [
            Expanded(child: _summaryValue('Charged', _money(charged))),
            Expanded(
                child: _summaryValue('Paid', _money(paid), alignEnd: true)),
          ],
        ),
        SizedBox(height: 12.r),
        Row(children: [
          Expanded(
              child: _summaryValue('Waived', _money(waived - reversedWaivers))),
          Expanded(
              child: _summaryValue('Due', _money(outstanding.clamp(0, 1 << 60)),
                  alignEnd: true)),
        ]),
        if (context.read<PreferencesStorage>().hasPermission('PAYMENT_WAIVE') &&
            outstanding > 0) ...[
          SizedBox(height: 12.r),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showWaiverForm(outstanding),
                icon: Icon(Iconsax.receipt_text, size: 17.r),
                label: const Text('Approve settlement waiver'),
              )),
        ],
        SizedBox(height: 10.r),
        _waiverHistory(),
        SizedBox(height: 24.r),
        _sectionTitle(_isOwnSubscription ? 'Payments' : 'Payment requests'),
        SizedBox(height: 8.r),
        _paymentSection(outstanding),
        SizedBox(height: 24.r),
        _sectionTitle('Activity'),
        SizedBox(height: 8.r),
        _ledgerTimeline(entries),
      ],
    );
  }

  Widget _paymentSection(int outstandingMinorUnit) {
    final hasOpenRequest = _paymentRequests.any((request) =>
        request.status == 'REQUESTED' || request.status == 'NEEDS_INFORMATION');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.r),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_paymentRequests.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 3.r),
              child: Text(
                'No payment requests yet.',
                style: TextStyle(color: Color(0xFF777777), fontSize: 13.r),
              ),
            ),
          ..._paymentRequests.asMap().entries.map(
                (item) => _paymentRow(item.value, item.key == 0),
              ),
          if (!_isOwnSubscription && _paymentRequests.isNotEmpty) ...[
            Divider(height: 18.r),
            Text(
              'Submitted payment details are shown above for review. Editing is available only to the member who submitted the request.',
              style: TextStyle(color: Color(0xFF777777), fontSize: 11.r),
            ),
          ],
          if (_isOwnSubscription && hasOpenRequest) ...[
            Divider(height: 18.r),
            Text(
              hasOpenRequest &&
                      _paymentRequests.any(
                        (request) => request.status == 'NEEDS_INFORMATION',
                      )
                  ? 'Branch requested more information. Update your payment submission below.'
                  : 'Your payment request is waiting for branch review.',
              style: TextStyle(color: Color(0xFF777777), fontSize: 11.r),
            ),
          ],
          if (_isOwnSubscription &&
              outstandingMinorUnit > 0 &&
              !hasOpenRequest) ...[
            if (_paymentRequests.isNotEmpty) Divider(height: 18.r),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showPaymentRequestForm(outstandingMinorUnit),
                icon: Icon(Iconsax.document_upload, size: 17.r),
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
      padding: EdgeInsets.only(top: first ? 0 : 10.r),
      child: Row(
        children: [
          Container(
            width: 34.r,
            height: 34.r,
            decoration: BoxDecoration(
              color: hasReceipt
                  ? const Color(0xFFE8F7EF)
                  : const Color(0xFFFFF2E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasReceipt ? Iconsax.receipt_text : Iconsax.money_time,
              size: 17.r,
              color: hasReceipt
                  ? const Color(0xFF198754)
                  : const Color(0xFFD95B00),
            ),
          ),
          SizedBox(width: 10.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.method} · ${_money(request.amountMinorUnit)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.r,
                  ),
                ),
                SizedBox(height: 3.r),
                Text(
                  request.reason == null || request.reason!.isEmpty
                      ? _pretty(status)
                      : '${_pretty(status)} · ${request.reason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11.r,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View payment details',
            onPressed: () => _openPaymentDetail(request),
            icon: Icon(Iconsax.arrow_right_3, size: 18.r),
            color: const Color(0xFF999999),
            visualDensity: VisualDensity.compact,
          ),
          if (hasReceipt)
            IconButton(
              tooltip: 'View receipt',
              onPressed: () => _viewReceipt(request),
              icon: Icon(Iconsax.receipt_text, size: 19.r),
              color: const Color(0xFFD95B00),
              visualDensity: VisualDensity.compact,
            )
          else ...[
            _badge(_pretty(status), color: _statusColor(status)),
            if (_isOwnSubscription &&
                (status == 'REQUESTED' || status == 'NEEDS_INFORMATION'))
              IconButton(
                tooltip: 'Edit submission',
                onPressed: () => _showPaymentRequestForm(
                  0,
                  existingRequest: request,
                ),
                icon: Icon(Iconsax.edit_2, size: 17.r),
                color: const Color(0xFFD95B00),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ],
      ),
    );
  }

  void _openPaymentDetail(PaymentRequestModel request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailPage(requestId: request.id),
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
      padding: EdgeInsets.fromLTRB(13.r, 14.r, 13.r, 5.r),
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
            width: 25.r,
            child: Column(
              children: [
                Container(
                  width: 10.r,
                  height: 10.r,
                  margin: EdgeInsets.only(top: 4.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD95B00),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.r,
                      margin: EdgeInsets.symmetric(vertical: 4.r),
                      color: const Color(0xFFF0D8C7),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 14.r),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.r,
                          ),
                        ),
                        SizedBox(height: 3.r),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 11.r,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.r),
                  Text(
                    amount,
                    style: TextStyle(
                      color: Color(0xFFD95B00),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.r,
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
          style: TextStyle(color: Color(0xFF777777), fontSize: 11.r),
        ),
        SizedBox(height: 4.r),
        Text(
          value,
          style: TextStyle(fontSize: 14.r, fontWeight: FontWeight.w800),
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
      padding: EdgeInsets.all(20.r),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 28.r, color: const Color(0xFFD95B00)),
          SizedBox(height: 9.r),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4.r),
          Text(
            message,
            style: TextStyle(color: Color(0xFF777777), fontSize: 12.r),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? avatarUrl, String name,
      {required String status, required String role}) {
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final child = CircleAvatar(
      radius: 24.r,
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
    return GestureDetector(
      onTap: () => showDailioMemberProfileSheet(
        context,
        DailioMemberPreview(
          memberId: widget.memberId,
          name: name,
          role: role,
          status: status,
          avatarUrl: avatarUrl,
        ),
      ),
      child: child,
    );
  }

  Widget _badge(String text, {required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.r,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Color(0xFF171717),
        fontSize: 15.r,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.r),
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
            padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 14.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.receipt_text, color: Colors.white, size: 19.r),
                    SizedBox(width: 8.r),
                    Expanded(
                      child: Text(
                        'Official Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.r,
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
                SizedBox(height: 10.r),
                RepaintBoundary(
                  key: _receiptKey,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8.r),
                    child: ClipPath(
                      clipper: _ReceiptEdgeClipper(),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(18.r, 20.r, 18.r, 18.r),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Dailio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18.r,
                                    ),
                                  ),
                                  SizedBox(height: 3.r),
                                  Text(
                                    '${preferences.activeOrganizationName ?? 'Dailio'} · ${preferences.activeBranchName ?? 'Branch'}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF777777),
                                        fontSize: 10.r),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 13.r),
                              child: Divider(height: 1.r),
                            ),
                            _receiptLine('RECEIPT NO',
                                receipt['receipt_number']?.toString()),
                            _receiptLine(
                                'DATE & TIME', _dateTime(receipt['issued_at'])),
                            SizedBox(height: 5.r),
                            Text(
                              'MEMBER & BUYER DETAILS',
                              style: TextStyle(
                                color: Color(0xFFD95B00),
                                fontSize: 9.r,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 7.r),
                            _receiptLine('Member', memberName),
                            _receiptLine('Plan', planName),
                            _receiptLine(
                                'Payment', payment['method']?.toString()),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.r),
                              child: Divider(height: 1.r),
                            ),
                            _receiptLine(
                              'TOTAL PAID',
                              _money((payment['amount_minor_unit'] as num?)
                                      ?.toInt() ??
                                  0),
                              emphasize: true,
                            ),
                            SizedBox(height: 12.r),
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.r, vertical: 5.r),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFFF7600)),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'PAID · CONFIRMED',
                                  style: TextStyle(
                                    color: Color(0xFFD95B00),
                                    fontSize: 9.r,
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
                SizedBox(height: 12.r),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharingReceipt ? null : _shareReceipt,
                        icon: _sharingReceipt
                            ? SizedBox(
                                width: 16.r,
                                height: 16.r,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.r,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Iconsax.share, size: 17.r),
                        label: const Text('Share receipt'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.r),
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
      padding: EdgeInsets.only(bottom: 9.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62.r,
            child: Text(
              label,
              style: TextStyle(color: Color(0xFF777777), fontSize: 12.r),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.isEmpty ? '—' : value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
                fontSize: emphasize ? 15.r : 12.r,
                color: emphasize ? const Color(0xFFD95B00) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWaivers() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    final subscriptionId = widget.subscriptionId;
    if (branchId == null || subscriptionId == null) return;
    setState(() {
      _waiversLoading = true;
      _waiversError = null;
    });
    try {
      final response = await context
          .read<FeesRepository>()
          .listSettlementWaivers(branchId, subscriptionId, page: _waiverPage);
      if (!mounted) return;
      final raw = response['data'] as List? ?? [];
      final meta = response['meta'] as Map?;
      setState(() {
        _waivers = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _waiverTotal = (meta?['total'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) setState(() => _waiversError = error.toString());
    } finally {
      if (mounted) setState(() => _waiversLoading = false);
    }
  }

  Widget _waiverHistory() {
    final prefs = context.read<PreferencesStorage>();
    if (!prefs.hasPermission('PAYMENT_READ_SELF') &&
        !prefs.hasPermission('PAYMENT_READ_ALL') &&
        !prefs.hasPermission('PAYMENT_WAIVE')) {
      return const SizedBox.shrink();
    }
    final canReverse = prefs.hasPermission('PAYMENT_WAIVE');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(
        onPressed: () {
          setState(() => _waiversOpen = !_waiversOpen);
          if (_waiversOpen) _loadWaivers();
        },
        icon: Icon(Iconsax.receipt_text, size: 17.r),
        label:
            Text(_waiversOpen ? 'Hide waiver history' : 'View waiver history'),
      ),
      if (_waiversOpen) ...[
        if (_waiversLoading) const Center(child: CircularProgressIndicator()),
        if (_waiversError != null)
          TextButton(
            onPressed: _loadWaivers,
            child: const Text('Could not load waivers. Try again'),
          ),
        if (!_waiversLoading && _waiversError == null && _waivers.isEmpty)
          const Text('No waivers recorded.'),
        ..._waivers.map((waiver) => Card(
              child: Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                _money((waiver['amount_minor_unit'] as num?)
                                        ?.toInt() ??
                                    0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        Text(waiver['reversal_id'] == null
                            ? 'Posted'
                            : 'Reversed'),
                      ]),
                      SizedBox(height: 5.r),
                      Text(waiver['reason']?.toString() ?? ''),
                      SizedBox(height: 5.r),
                      Text(_dateTime(waiver['created_at']),
                          style: TextStyle(
                              color: const Color(0xFF777777), fontSize: 12.r)),
                      if (canReverse && waiver['reversal_id'] == null)
                        TextButton.icon(
                          onPressed: () =>
                              _reverseWaiver(waiver['id'].toString()),
                          icon: Icon(Iconsax.undo, size: 16.r),
                          label: const Text('Reverse waiver'),
                        ),
                    ],
                  )),
            )),
        if (_waiverTotal > 20)
          Row(children: [
            TextButton(
                onPressed: _waiverPage <= 1
                    ? null
                    : () {
                        setState(() => _waiverPage--);
                        _loadWaivers();
                      },
                child: const Text('Previous')),
            Text('Page $_waiverPage'),
            TextButton(
                onPressed: _waiverPage * 20 >= _waiverTotal
                    ? null
                    : () {
                        setState(() => _waiverPage++);
                        _loadWaivers();
                      },
                child: const Text('Next')),
          ]),
      ],
    ]);
  }

  Future<void> _reverseWaiver(String waiverId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Reverse this waiver?'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'A new ledger charge will restore the due. The original waiver stays in history.'),
                TextField(
                    controller: controller,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Reason')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, controller.text.trim()),
                    child: const Text('Continue')),
              ],
            ));
    controller.dispose();
    if (!mounted || reason == null) return;
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a reason of at least 10 characters.')));
      return;
    }
    final confirmed = await showConfirmDialog(context,
        title: 'Restore the due?',
        message:
            'This will post a new debit for the waived amount and retain the original record.',
        confirmLabel: 'Reverse waiver',
        icon: Iconsax.undo);
    if (confirmed != true || !mounted) return;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null || widget.subscriptionId == null) return;
    try {
      await context.read<FeesRepository>().reverseSettlementWaiver(
          branchId, widget.subscriptionId!, waiverId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Waiver reversed. Due restored in the ledger.')));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not reverse waiver: $error')));
      }
    }
  }

  Future<void> _showWaiverForm(int outstandingMinorUnit) async {
    final amountController =
        TextEditingController(text: formatMoneyInput(outstandingMinorUnit));
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Settlement waiver'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'This reduces the due but is not cash received. The original charge remains in history.',
                    style: TextStyle(fontSize: 12)),
                TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Waiver amount (INR)')),
                TextField(
                    controller: reasonController,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                        labelText: 'Reason (at least 10 characters)')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, {
                          'amount': amountController.text,
                          'reason': reasonController.text.trim(),
                        }),
                    child: const Text('Continue'))
              ],
            ));
    amountController.dispose();
    reasonController.dispose();
    if (result == null || !mounted) return;
    final amount = parseMoneyMinor(result['amount'] ?? '');
    final reason = result['reason']?.trim() ?? '';
    if (amount == null || amount > outstandingMinorUnit || reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enter a valid amount up to the due and a reason of at least 10 characters.')));
      return;
    }
    final confirmed = await showConfirmDialog(context,
        title: 'Approve this concession?',
        message:
            'The branch ledger will record a separate waiver of ${_money(amount)}. It will not count as cash paid.',
        confirmLabel: 'Post waiver',
        icon: Iconsax.receipt_text);
    if (confirmed != true || !mounted) return;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null || widget.subscriptionId == null) return;
    try {
      await context.read<FeesRepository>().createSettlementWaiver(
          branchId, widget.subscriptionId!, amount, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Waiver posted; due recalculated from the ledger.')));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not post waiver: $error')));
      }
    }
  }

  Future<void> _showPaymentRequestForm(
    int outstandingMinorUnit, {
    PaymentRequestModel? existingRequest,
  }) async {
    final isEditing = existingRequest != null;
    final amountController = TextEditingController(
      text: formatMoneyInput(
          isEditing ? existingRequest.amountMinorUnit : outstandingMinorUnit),
    );
    final referenceController = TextEditingController(
      text: existingRequest?.reference ?? '',
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Iconsax.document_upload, color: Color(0xFFD95B00)),
            SizedBox(width: 9.r),
            Text(isEditing ? 'Edit payment submission' : 'Submit evidence'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (INR)',
                prefixIcon: Icon(Iconsax.money_3, size: 18.r),
              ),
            ),
            TextField(
              controller: referenceController,
              decoration: InputDecoration(
                labelText: 'Reference / UPI ID',
                prefixIcon: Icon(Iconsax.receipt_text, size: 18.r),
              ),
            ),
            SizedBox(height: 8.r),
            Text(
              isEditing
                  ? 'Update the details requested by the branch. You can keep the existing receipt or attach a new one.'
                  : 'Add a reference or attach a receipt so staff can verify the request.',
              style: TextStyle(fontSize: 12.r, color: Color(0xFF777777)),
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
            child: Text(isEditing ? 'Save changes' : 'Submit'),
          ),
        ],
      ),
    );
    amountController.dispose();
    referenceController.dispose();
    if (result == null || !mounted) return;
    final amount = parseMoneyMinor(result['amount'] ?? '');
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    final subscriptionId = widget.subscriptionId;
    if (branchId == null ||
        subscriptionId == null ||
        amount == null ||
        amount > outstandingMinorUnit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enter a valid payment amount no greater than the due.')));
      return;
    }
    try {
      final repository = context.read<FeesRepository>();
      final evidence = await _uploadEvidence(repository, branchId);
      final reference = (result['reference'] ?? '').trim();
      if (!isEditing && evidence == null && reference.isEmpty) {
        throw Exception('Attach a receipt or enter a payment reference');
      }
      final evidencePayload = [
        if (evidence != null)
          {
            'storage_key': evidence['storage_key'],
            'content_type': evidence['content_type'],
            'size_bytes': evidence['size_bytes'],
          },
      ];
      if (isEditing) {
        await repository.updatePaymentRequest(
          branchId,
          existingRequest.id,
          {
            'amount_minor_unit': amount,
            'method': existingRequest.method,
            'reference': reference.isEmpty ? null : reference,
            if (evidence != null) 'evidence': evidencePayload,
          },
        );
      } else {
        await repository.createPaymentRequest(
          branchId,
          {
            'subscription_id': subscriptionId,
            'amount_minor_unit': amount,
            'currency': 'INR',
            'method': 'UPI',
            if (reference.isNotEmpty) 'reference': reference,
            'evidence': evidencePayload,
          },
          idempotencyKey:
              'mobile-payment-$subscriptionId-${DateTime.now().toUtc().toIso8601String()}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Payment submission updated for review'
                : 'Payment request submitted for review',
          ),
        ),
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

  String _money(int minor) => formatMoneyMinor(minor);

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
