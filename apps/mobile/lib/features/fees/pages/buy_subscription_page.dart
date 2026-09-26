import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/router/route_names.dart';
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
    try {
      final plans = await context
          .read<OrganizationRepository>()
          .getOrganizationPlans(organizationId, branchId: branchId);
      if (!mounted) return;
      setState(() {
        _plans = plans.where((plan) => plan['is_active'] == true).toList();
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
    final preferences = context.watch<PreferencesStorage>();
    final branchName = preferences.activeBranchName ?? 'Active branch';
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Buy a plan'),
          Text(branchName, style: const TextStyle(fontSize: 12)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Choose the plan that works for you',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                          'Your request will be sent to the branch for review.',
                          style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 18),
                      if (_plans.isEmpty)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                    'No active plans are available right now.')))
                      else
                        ..._plans.map(_planCard),
                    ],
                  ),
                ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final amount = (plan['amount_minor_unit'] as num?)?.toInt() ?? 0;
    final joining = (plan['joining_fee_minor'] as num?)?.toInt() ?? 0;
    final currency = plan['currency']?.toString() ?? 'INR';
    final duration = plan['duration_days']?.toString() ?? '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPurchase(plan),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(plan['name']?.toString() ?? 'Plan',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ]),
            if ((plan['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(plan['description'].toString(),
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              _detail('$duration days', 'Coverage'),
              const Spacer(),
              _detail(
                  '$currency ${(amount / 100).toStringAsFixed(0)}', 'Plan fee'),
            ]),
            if (joining > 0) ...[
              const SizedBox(height: 10),
              Text(
                  'Admission fee: $currency ${(joining / 100).toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detail(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      );

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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
