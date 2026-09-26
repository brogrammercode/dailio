import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../fees/controllers/fees_repository.dart';
import '../../fees/models/fee_models.dart';
import 'payment_detail_page.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  String? _error;
  List<PaymentRequestModel> _requests = [];
  String _period = 'this_month';

  static const _periods = <String, String>{
    'today': 'Today',
    'yesterday': 'Yesterday',
    'this_week': 'This week',
    'this_month': 'This month',
    'this_year': 'This year',
  };

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
        _error = 'Select an active branch to view payments.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await context
          .read<FeesRepository>()
          .listPaymentRequests(branchId, period: _period);
      if (!mounted) return;
      setState(() {
        _requests = requests;
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: const Text('Payments'),
          backgroundColor: Colors.white,
          elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _buildPeriodTabs(),
                      const SizedBox(height: 16),
                      if (_requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 140),
                          child: Center(
                              child: Text('No payments in this period.')),
                        )
                      else
                        ..._requests.map((request) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _requestCard(request),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPeriodTabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _periods.entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _period == entry.key,
                      onSelected: (_) async {
                        if (_period == entry.key) return;
                        setState(() => _period = entry.key);
                        await _load();
                      },
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _requestCard(PaymentRequestModel request) {
    final canReview = context.read<PreferencesStorage>().canReviewPayments;
    final canAct = canReview &&
        (request.status == 'REQUESTED' ||
            request.status == 'NEEDS_INFORMATION');
    final color = _statusColor(request.status);
    final memberName = request.memberName ?? 'Member';
    final avatarUrl = request.memberAvatarUrl;
    final date = request.payment?.postedAt ?? request.createdAt;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentDetailPage(requestId: request.id))),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                    ? null
                    : NetworkImage(avatarUrl),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        memberName.isEmpty ? '?' : memberName[0].toUpperCase(),
                        style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memberName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(request.planName ?? 'Subscription payment',
                          style: TextStyle(color: Colors.grey.shade700)),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                            DateFormat('dd MMM yyyy, hh:mm a')
                                .format(date.toLocal()),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_money(request.signedAmountMinorUnit),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _statusBadge(request.status, color),
              ]),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _infoChip(Icons.account_balance_wallet_outlined, request.method),
              _infoChip(
                  Icons.attach_file, '${request.evidence.length} evidence'),
              if (request.reference != null && request.reference!.isNotEmpty)
                _infoChip(Icons.tag, request.reference!),
              if (request.payment?.receipt != null)
                _infoChip(Icons.receipt_long,
                    request.payment!.receipt!.receiptNumber),
            ]),
            if (request.reason != null && request.reason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(request.reason!,
                  style:
                      TextStyle(color: Colors.orange.shade900, fontSize: 12)),
            ],
            if (canAct) ...[
              const Divider(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _review(request.id, 'approve'),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: () => _review(request.id, 'needs_information'),
                    child: const Text('Need info'),
                  ),
                  TextButton(
                    onPressed: () => _review(request.id, 'reject'),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status.replaceAll('_', ' '),
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
          ),
        ]),
      );

  Color _statusColor(String status) => switch (status) {
        'APPROVED' => Colors.green.shade700,
        'REJECTED' => Colors.red.shade700,
        'NEEDS_INFORMATION' => Colors.orange.shade800,
        'CANCELLED' => Colors.grey.shade700,
        _ => Colors.blue.shade700,
      };

  Future<void> _review(String requestId, String action) async {
    final preferences = context.read<PreferencesStorage>();
    final repository = context.read<FeesRepository>();
    String? reason;
    if (action != 'approve') {
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(
                action == 'reject' ? 'Reject payment' : 'Request information'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Explain what is needed',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(dialogContext, value);
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
      if (reason == null) return;
    }

    if (!mounted) return;
    final branchId = preferences.activeBranchId;
    if (branchId == null) return;
    try {
      await repository.reviewPaymentRequest(
        branchId,
        requestId,
        action,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Payment request ${action.replaceAll('_', ' ')}.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update payment: $error')),
      );
    }
  }

  String _money(int minor) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2)
          .format(minor / 100);
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
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ));
}
