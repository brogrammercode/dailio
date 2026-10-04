import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../organization/controllers/organization_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      final plans =
          await context.read<OrganizationRepository>().getOrganizationPlans(
        organizationId,
        branchId: branchId,
        onFresh: (freshPlans) {
          if (!mounted) return;
          final activePlans =
              freshPlans.where((plan) => plan['is_active'] == true).toList();
          setState(() {
            _plans = activePlans;
            if (_selectedPlan != null &&
                !activePlans
                    .any((plan) => plan['id'] == _selectedPlan!['id'])) {
              _selectedPlan = null;
            }
          });
        },
      );
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
              padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 0),
              child: ShimmerLoader.planList(),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.r, 20.r, 16.r, 30.r),
                    children: [
                      Text(
                        'Select Plan',
                        style: TextStyle(
                          fontSize: 22.r,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 5.r),
                      Text(
                        'Choose duration to renew or start subscription',
                        style: TextStyle(color: _muted, fontSize: 12.r),
                      ),
                      SizedBox(height: 20.r),
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
      title: Text(
        'Dailio',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.r),
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
        SizedBox(width: 8.r),
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
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 14.r),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF9F3) : Colors.white,
          border: Border(
            left: BorderSide(
              color: selected ? _orange : Colors.transparent,
              width: 3.r,
            ),
            bottom: const BorderSide(color: Color(0xFFEDEDED)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 9.r,
              height: 9.r,
              decoration: BoxDecoration(
                color: selected ? _orange : const Color(0xFFD9D9D9),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12.r),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      plan['name']?.toString() ?? 'Plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13.r,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 5.r),
                  Text(
                    '· $durationText',
                    style: TextStyle(color: _muted, fontSize: 11.r),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              _selectedBadge(),
              SizedBox(width: 8.r),
            ],
            Text(
              _money(amount),
              style: TextStyle(
                color: _ink,
                fontSize: 13.r,
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
      padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 3.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9D6),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        'SELECTED',
        style: TextStyle(
          color: _orange,
          fontSize: 8.r,
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
        padding: EdgeInsets.fromLTRB(16.r, 10.r, 16.r, 14.r),
        child: SizedBox(
          height: 48.r,
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _openPurchase(plan),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9.r),
              ),
            ),
            child: Text(
              'Continue with ${plan['name'] ?? 'plan'}  ·  ${_money(amount)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPlans() {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(Iconsax.card_remove, size: 30.r, color: _muted),
          SizedBox(height: 8.r),
          Text(
            'No active plans are available right now.',
            style: TextStyle(color: _muted, fontSize: 12.r),
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
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.cloud_cross, size: 38.r, color: Color(0xFF777777)),
              SizedBox(height: 12.r),
              Text(message, textAlign: TextAlign.center),
              SizedBox(height: 12.r),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: Icon(Iconsax.refresh, size: 16.r),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
