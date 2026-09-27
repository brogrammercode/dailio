import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../organization/controllers/organization_repository.dart';

class BuySubscriptionPage extends StatefulWidget {
  const BuySubscriptionPage({super.key});

  @override
  State<BuySubscriptionPage> createState() => _BuySubscriptionPageState();
}

class _BuySubscriptionPageState extends State<BuySubscriptionPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = context.read<PreferencesStorage>();
    final organizationId = preferences.activeOrganizationId;
    final branchId = preferences.activeBranchId;
    if (organizationId == null || branchId == null) {
      setState(() {
        _loading = false;
        _error = 'Select an active branch before buying a plan.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await context
          .read<OrganizationRepository>()
          .getOrganizationPlans(organizationId, branchId: branchId);
      if (!mounted) return;
      setState(() {
        _plans = plans.where((plan) => plan['is_active'] == true).toList();
        if (_selectedPlan != null &&
            !_plans.any((plan) => plan['id'] == _selectedPlan!['id'])) {
          _selectedPlan = null;
        }
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
    final showContinue = !_loading && _error == null && _selectedPlan != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      bottomNavigationBar: showContinue ? _continueBar() : null,
      body: _loading
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ShimmerLoader.compactList(),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                    children: [
                      Text(
                        'Select Plan',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Choose duration to renew or start subscription',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      if (_plans.isEmpty)
                        _emptyPlans()
                      else
                        ..._plans.map(_planRow),
                    ],
                  ),
                ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Dailio',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      actions: [
        DailioOverflowMenu<String>(
          items: const [
            DailioMenuItem(
              value: 'refresh',
              icon: Iconsax.refresh,
              label: 'Refresh plans',
            ),
          ],
          onSelected: (_) => _load(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _planRow(Map<String, dynamic> plan) {
    final selected = _selectedPlan?['id'] == plan['id'];
    final amount = (plan['amount_minor_unit'] as num?)?.toInt() ?? 0;
    final duration = (plan['duration_days'] as num?)?.toInt() ?? 0;
    final durationText = '$duration days';
    return InkWell(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF9F3) : Colors.white,
          border: Border(
            left: BorderSide(
              color: selected ? _orange : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFFEDEDED)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: selected ? _orange : const Color(0xFFD9D9D9),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      plan['name']?.toString() ?? 'Plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '· $durationText',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              _selectedBadge(),
              const SizedBox(width: 8),
            ],
            Text(
              _money(amount),
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9D6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'SELECTED',
        style: TextStyle(
          color: _orange,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _continueBar() {
    final plan = _selectedPlan!;
    final amount = (plan['amount_minor_unit'] as num?)?.toInt() ?? 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _openPurchase(plan),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Text(
              'Continue with ${plan['name'] ?? 'plan'}  ·  ${_money(amount)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPlans() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Iconsax.card_remove, size: 30, color: _muted),
          SizedBox(height: 8),
          Text(
            'No active plans are available right now.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openPurchase(Map<String, dynamic> plan) {
    final preferences = context.read<PreferencesStorage>();
    final branchId = preferences.activeBranchId;
    if (branchId == null) return;
    context.push(AppRoutes.subscriptionPurchase, extra: {
      'direct_plan': true,
      'plan': plan,
      'branch': {
        'id': branchId,
        'name': preferences.activeBranchName ?? 'Branch',
      },
    });
  }

  String _money(int minor) => '₹${(minor / 100).toStringAsFixed(0)}';

  static const _orange = Color(0xFFD95B00);
  static const _ink = Color(0xFF171717);
  static const _muted = Color(0xFF777777);
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.cloud_cross,
                  size: 38, color: Color(0xFF777777)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Iconsax.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
