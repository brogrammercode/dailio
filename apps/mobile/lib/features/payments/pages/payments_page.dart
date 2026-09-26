import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/shimmer_loader.dart';
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
  String _status = 'ALL';

  static const _periods = <String, String>{
    'today': 'Today',
    'yesterday': 'Yesterday',
    'this_week': 'This week',
    'this_month': 'This month',
    'this_year': 'This year',
  };

  static const _statuses = <String, String>{
    'ALL': 'All',
    'PAID': 'Paid',
    'REQUESTED': 'Requested',
    'PENDING': 'Pending',
    'REJECTED': 'Rejected',
  };

  List<PaymentRequestModel> get _visibleRequests {
    return _requests.where((request) {
      switch (_status) {
        case 'PAID':
          return request.payment?.status == 'SUCCESS' ||
              request.status == 'APPROVED';
        case 'PENDING':
          return request.status == 'NEEDS_INFORMATION';
        case 'REJECTED':
          return request.status == 'REJECTED' || request.status == 'CANCELLED';
        case 'REQUESTED':
          return request.status == 'REQUESTED';
        default:
          return true;
      }
    }).toList();
  }

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dailio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          DailioOverflowMenu<String>(
            items: const [
              DailioMenuItem(
                value: 'refresh',
                icon: Icons.refresh,
                label: 'Refresh',
              ),
            ],
            onSelected: (_) => _load(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStatusTabs(),
          _buildPeriodTabs(),
          Expanded(
            child: _loading
                ? ShimmerLoader.compactList()
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _visibleRequests.isEmpty
                            ? ListView(
                                padding: const EdgeInsets.only(top: 140),
                                children: const [
                                  Center(
                                      child: Text(
                                          'No payments match this filter.')),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.only(top: 12, bottom: 96),
                                itemCount: _visibleRequests.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) =>
                                    _requestCard(_visibleRequests[index]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() => DailioTabStrip<String>(
        tabs: _statuses.entries
            .map((entry) => DailioTabItem(value: entry.key, label: entry.value))
            .toList(),
        selected: _status,
        onChanged: (value) => setState(() => _status = value),
      );

  Widget _buildPeriodTabs() => DailioTabStrip<String>(
        tabs: _periods.entries
            .map((entry) => DailioTabItem(value: entry.key, label: entry.value))
            .toList(),
        selected: _period,
        onChanged: (value) async {
          if (_period == value) return;
          setState(() => _period = value);
          await _load();
        },
      );

  Widget _requestCard(PaymentRequestModel request) {
    final preferences = context.read<PreferencesStorage>();
    final canAct = preferences.canReviewPayments &&
        (request.status == 'REQUESTED' ||
            request.status == 'NEEDS_INFORMATION');
    final memberName = request.memberName ?? 'Member';
    final roleLabel = request.memberRoleName ?? request.planName ?? 'Member';
    final amount = _money(request.signedAmountMinorUnit);
    final date = request.payment?.postedAt ?? request.createdAt;
    final isDeduct = request.signedAmountMinorUnit < 0;
    final displayAmount = _money(request.signedAmountMinorUnit.abs());
    final directionLabel = isDeduct ? 'Deduct' : 'Credit';
    final directionColor = isDeduct ? AppColors.error : AppColors.brandDark;
    final directionIcon = isDeduct ? Icons.arrow_downward : Icons.arrow_upward;
    final subtitle = request.payment?.status == 'SUCCESS'
        ? 'Paid $amount · ${request.method}'
        : switch (request.status) {
            'REQUESTED' => 'Payment requested · $amount',
            'NEEDS_INFORMATION' => 'Information needed · $amount',
            'REJECTED' => 'Payment rejected · $amount',
            'CANCELLED' => 'Payment cancelled · $amount',
            _ => 'Payment pending · $amount',
          };
    final color = _statusColor(request.status);

    return DailioCompactTile(
      avatar: _avatar(request, color, directionIcon),
      title: memberName,
      titleBadge: roleLabel,
      statusBadge: directionLabel,
      statusBadgeColor: directionColor,
      subtitle: _paymentSubtitle(request, displayAmount, subtitle),
      trailing:
          date == null ? '--' : DateFormat('dd MMM').format(date.toLocal()),
      subtitleColor: directionColor,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentDetailPage(requestId: request.id))),
      menuItems: [
        const DailioMenuItem(
          value: 'details',
          icon: Icons.receipt_long_outlined,
          label: 'View payment details',
        ),
        if (canAct) ...[
          const DailioMenuItem(
            value: 'approve',
            icon: Icons.check_circle_outline,
            label: 'Approve',
          ),
          const DailioMenuItem(
            value: 'needs_information',
            icon: Icons.help_outline,
            label: 'Need information',
          ),
          const DailioMenuItem(
            value: 'reject',
            icon: Icons.cancel_outlined,
            label: 'Reject',
            destructive: true,
          ),
        ],
      ],
      onMenuSelected: (value) {
        if (value == 'details') {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PaymentDetailPage(requestId: request.id)));
        } else if (value == 'approve' ||
            value == 'needs_information' ||
            value == 'reject') {
          _review(request.id, value);
        }
      },
    );
  }

  String _paymentSubtitle(
      PaymentRequestModel request, String amount, String fallback) {
    if (request.payment?.status == 'SUCCESS') {
      return 'Paid $amount · ${request.method}';
    }
    switch (request.status) {
      case 'REQUESTED':
        return 'Payment requested · $amount';
      case 'NEEDS_INFORMATION':
        return 'Information needed · $amount';
      case 'REJECTED':
        return 'Payment rejected · $amount';
      case 'CANCELLED':
        return 'Payment cancelled · $amount';
      default:
        return fallback;
    }
  }

  // ignore: unused_element
  Widget _requestCardLegacy(PaymentRequestModel request) {
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

  Widget _avatar(
      PaymentRequestModel request, Color statusColor, IconData statusIcon) {
    final memberName = request.memberName ?? 'Member';
    final image = request.memberAvatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.brandAccent.withValues(alpha: 0.12),
          backgroundImage:
              image == null || image.isEmpty ? null : NetworkImage(image),
          child: image == null || image.isEmpty
              ? Text(
                  memberName.isEmpty ? '?' : memberName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.brandAccent,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(statusIcon, size: 10, color: Colors.white),
          ),
        ),
      ],
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
        'APPROVED' => AppColors.brandDark,
        'REJECTED' => AppColors.error,
        'NEEDS_INFORMATION' => AppColors.brandAccent,
        'CANCELLED' => const Color(0xFF6B6B6B),
        _ => AppColors.brandAccent,
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
