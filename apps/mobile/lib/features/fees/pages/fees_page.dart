import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../controllers/fees_repository.dart';
import '../models/fee_models.dart';
import 'member_subscription_detail_page.dart';

class FeesPage extends StatefulWidget {
  const FeesPage({super.key});

  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  late final FeesRepository _repository;
  bool _loading = true;
  String? _error;
  String _period = 'this_month';
  String _status = 'ALL';
  DateTime? _from;
  DateTime? _to;
  List<FeeCardModel> _cards = [];

  @override
  void initState() {
    super.initState();
    _repository = context.read<FeesRepository>();
    _load();
  }

  Future<void> _load() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'Select an active branch to view fees.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _repository.listFees(branchId,
          period: _period, from: _from, to: _to);
      if (mounted) {
        setState(() {
          _cards = cards;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  List<FeeCardModel> get _visibleCards => _status == 'ALL'
      ? _cards
      : _cards.where((card) => card.status == _status).toList();

  bool get _hasCurrentCoverage => _cards.any((card) {
        final status = card.subscriptionStatus?.toUpperCase();
        final endDate = card.endDate;
        return card.subscriptionId != null &&
            endDate != null &&
            endDate.isAfter(DateTime.now()) &&
            status != 'CANCELLED' &&
            status != 'EXPIRED';
      });

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<PreferencesStorage>();
    final branchName = preferences.activeBranchName ?? 'Active branch';
    final canReadAll = preferences.canReadAllFees;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Fees & Subscriptions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(branchName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      if (canReadAll) ...[
                        _buildSummary(),
                        const SizedBox(height: 16),
                        _buildPeriodTabs(),
                        const SizedBox(height: 12),
                        _buildStatusTabs(),
                        const SizedBox(height: 16),
                        if (_visibleCards.isEmpty)
                          const _EmptyState()
                        else
                          ..._visibleCards.map(_buildCard),
                      ] else ...[
                        _buildMemberHeader(),
                        const SizedBox(height: 16),
                        if (_cards.isEmpty)
                          const _EmptyState()
                        else
                          _buildCard(_cards.first),
                        if (!_hasCurrentCoverage) ...[
                          const SizedBox(height: 4),
                          _buildBuyPlanButton(),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildMemberHeader() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: Colors.indigo.shade700, size: 30),
          const SizedBox(width: 12),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('View your coverage, balance, and payment status.'),
            ]),
          ),
        ]),
      );

  Widget _buildBuyPlanButton() => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push(AppRoutes.buyPlan),
          icon: const Icon(Icons.add_card),
          label: const Text('Buy a plan'),
        ),
      );

  Widget _buildSummary() {
    final counts = <String, int>{
      for (final state in _states)
        state: _cards.where((card) => card.status == state).length
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Expanded(child: _metric('Paid', counts['PAID'] ?? 0, Colors.green)),
        _divider(),
        Expanded(
            child:
                _metric('Requested', counts['REQUESTED'] ?? 0, Colors.orange)),
        _divider(),
        Expanded(
            child: _metric(
                'Pending',
                (counts['PENDING'] ?? 0) + (counts['EXPIRED'] ?? 0),
                Colors.red)),
      ]),
    );
  }

  static const _states = [
    'PAID',
    'REQUESTED',
    'PENDING',
    'PARTIALLY_PAID',
    'EXPIRING_SOON',
    'EXPIRED'
  ];

  Widget _metric(String label, int value, Color color) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]);

  Widget _divider() =>
      Container(width: 1, height: 34, color: Colors.grey.shade200);

  Widget _buildPeriodTabs() => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'this_month', label: Text('This Month')),
          ButtonSegment(value: 'last_month', label: Text('Last Month')),
          ButtonSegment(value: 'custom', label: Text('Custom')),
        ],
        selected: {_period},
        onSelectionChanged: (selection) async {
          final value = selection.first;
          if (value == 'custom') {
            final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now()));
            if (range == null) return;
            setState(() {
              _from = range.start;
              _to = range.end;
            });
          }
          if (value != 'custom') {
            _from = null;
            _to = null;
          }
          setState(() {
            _period = value;
            _status = 'ALL';
          });
          await _load();
        },
      );

  Widget _buildStatusTabs() {
    final tabs = <String, String>{
      'ALL': 'All',
      'PAID': 'Paid',
      'REQUESTED': 'Requested',
      'PENDING': 'Pending',
      'PARTIALLY_PAID': 'Partial',
      'EXPIRING_SOON': 'Expiring'
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: tabs.entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _status == entry.key,
                        onSelected: (_) => setState(() => _status = entry.key)),
                  ))
              .toList()),
    );
  }

  Widget _buildCard(FeeCardModel card) {
    final color = _statusColor(card.status);
    final endDate = card.endDate == null
        ? 'No coverage'
        : DateFormat('dd MMM yyyy').format(card.endDate!.toLocal());
    final showingPaidAmount = card.paidAmountMinorUnit > 0;
    final amount = NumberFormat.currency(
            locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0)
        .format((showingPaidAmount
                ? card.paidAmountMinorUnit
                : card.balanceMinorUnit) /
            100);
    final urgency = card.remainingDays == null
        ? 'No active coverage'
        : card.remainingDays! < 0
            ? 'Expired ${card.remainingDays!.abs()} days ago'
            : '${card.remainingDays} days remaining';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MemberSubscriptionDetailPage(
                    memberId: card.memberId,
                    subscriptionId: card.subscriptionId))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _avatar(card),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(card.memberName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15))),
              _statusBadge(card.status, color),
            ]),
            const SizedBox(height: 8),
            Text(card.planName ?? 'No active subscription',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text('Expiry: $endDate',
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600))),
              Text('${showingPaidAmount ? 'Paid' : 'Due'}: $amount',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: showingPaidAmount
                          ? Colors.green.shade700
                          : card.balanceMinorUnit > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700)),
            ]),
            const SizedBox(height: 4),
            Text(urgency,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (card.paymentDate != null || card.receiptNumber != null)
              Text(
                  'Paid: ${card.paymentDate == null ? '-' : DateFormat('dd MMM yyyy').format(card.paymentDate!.toLocal())}${card.receiptNumber == null ? '' : ' • Receipt ${card.receiptNumber}'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (card.paidEarlierCoveringPeriod)
              const Text(
                  'Paid earlier; this payment covers the selected period.',
                  style: TextStyle(fontSize: 11, color: Colors.blue)),
            if (card.pendingRequestId != null &&
                context.read<PreferencesStorage>().canReviewPayments) ...[
              const Divider(height: 18),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _reviewPayment(card.pendingRequestId!),
                    icon: const Icon(Icons.fact_check, size: 16),
                    label: const Text('Review payment'),
                  )),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _avatar(FeeCardModel card) {
    final image = card.avatarUrl;
    return CircleAvatar(
      radius: 21,
      backgroundColor: Colors.indigo.shade100,
      backgroundImage:
          image == null || image.isEmpty ? null : NetworkImage(image),
      child: image == null || image.isEmpty
          ? Text(
              card.memberName.isEmpty ? '?' : card.memberName[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.indigo.shade800, fontWeight: FontWeight.bold))
          : null,
    );
  }

  Future<void> _reviewPayment(String requestId) async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(
            title: Text('Review payment request'),
            subtitle: Text('Choose the server-side action')),
        ListTile(
            leading: const Icon(Icons.check, color: Colors.green),
            title: const Text('Approve'),
            onTap: () => Navigator.pop(sheetContext, 'approve')),
        ListTile(
            leading: const Icon(Icons.close, color: Colors.red),
            title: const Text('Reject'),
            onTap: () => Navigator.pop(sheetContext, 'reject')),
        ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Request information'),
            onTap: () => Navigator.pop(sheetContext, 'needs_information')),
      ])),
    );
    if (action == null || !mounted) return;
    String? reason;
    if (action != 'approve') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(action == 'reject'
              ? 'Rejection reason'
              : 'What information is needed?'),
          content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Enter a reason')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Continue')),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.isEmpty || !mounted) return;
    }
    try {
      await _repository.reviewPaymentRequest(branchId, requestId, action,
          reason: reason);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Review failed: $error')));
      }
    }
  }

  Widget _statusBadge(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status.replaceAll('_', ' '),
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green.shade700;
      case 'REQUESTED':
        return Colors.orange.shade800;
      case 'EXPIRING_SOON':
        return Colors.deepOrange.shade700;
      case 'PARTIALLY_PAID':
        return Colors.blue.shade700;
      case 'EXPIRED':
        return Colors.red.shade700;
      default:
        return Colors.red.shade700;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(40),
      child:
          Center(child: Text('No fee records match this period and status.')));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry'))
          ])));
}
