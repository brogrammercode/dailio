import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../branch/models/member_model.dart';

class AssignSubscriptionPage extends StatefulWidget {
  final MemberModel member;
  const AssignSubscriptionPage({super.key, required this.member});

  @override
  State<AssignSubscriptionPage> createState() => _AssignSubscriptionPageState();
}

class _AssignSubscriptionPageState extends State<AssignSubscriptionPage> {
  final Color _primaryBrown = const Color(0xFF8B4513);
  String? _selectedPlanId;
  List<dynamic> _plans = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId;
      final branchId = prefs.activeBranchId;
      if (orgId == null || branchId == null) return;
      final api = context.read<ApiClient>();
      final response = await api.dio.get('/organizations/$orgId/plans',
          queryParameters: {'branch_id': branchId});
      if (mounted) {
        setState(() {
          _plans = response.data['data'] ?? [];
          if (_plans.isNotEmpty) {
            _selectedPlanId = _plans[0]['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMemberHeader(),
          const SizedBox(height: 24),
          _buildSectionTitle('Choose Membership Plan', 'Billed in advance',
              Iconsax.medal_star),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
          else if (_plans.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'No plans found. Please create plans in admin settings.')))
          else
            ..._plans.map((p) {
              final currencyFormat = NumberFormat.currency(
                  locale: 'en_IN', symbol: '₹', decimalDigits: 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPlanOption(
                  id: p['id'],
                  title: p['name'],
                  price: currencyFormat.format(((p['amount_minor_unit'] ??
                          p['amountMinorUnit'] ??
                          0) as num) /
                      100),
                  duration:
                      '${p['duration_days'] ?? p['durationDays'] ?? 0} Days',
                  subtitle: p['description'] ?? '',
                  isSelected: _selectedPlanId == p['id'],
                  perks: [], // Add if needed
                ),
              );
            }),
          const SizedBox(height: 12),
          _buildSectionTitle('Payment Details', null, Iconsax.wallet),
          const SizedBox(height: 12),
          _buildPaymentSection(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Iconsax.tick_circle, size: 20),
            label: Text(_isSubmitting ? 'Saving…' : 'Submit & Activate',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final planId = _selectedPlanId;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (planId == null || branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a plan and active branch first')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      _idempotencyKey ??=
          'mobile-${widget.member.id}-$planId-${DateTime.now().toUtc().toIso8601String()}';
      await context.read<ApiClient>().dio.post(
            '/branches/$branchId/members/${widget.member.id}/subscriptions',
            data: {
              'plan_id': planId,
              'start_date': DateTime.now().toUtc().toIso8601String()
            },
            options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription assigned')));
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not assign subscription: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assign Subscription',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          Row(
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Main Branch',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: widget.member.avatarUrl != null
                ? NetworkImage(widget.member.avatarUrl ?? '')
                : null,
            child: widget.member.avatarUrl == null
                ? Text(
                    widget.member.name.isNotEmpty
                        ? widget.member.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.member.name,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Assigning new subscription',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4)),
            child: Text('Assisted Flow',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String? subtitle, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryBrown),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const Spacer(),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]
      ],
    );
  }

  Widget _buildPlanOption({
    required String id,
    required String title,
    required String price,
    required String duration,
    required String subtitle,
    required bool isSelected,
    required List<String> perks,
  }) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedPlanId = id;
        _idempotencyKey = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade50.withValues(alpha: 0.4)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(duration,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                    child: _buildPaymentMethodTab(
                        'UPI / QR', Icons.qr_code, true)),
                Expanded(
                    child: _buildPaymentMethodTab(
                        'Cash', Icons.point_of_sale, false)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.qr_code_2, size: 80, color: Colors.grey.shade800),
                const SizedBox(height: 8),
                const Text('Scan to pay',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTab(String label, IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? _primaryBrown : Colors.grey.shade500),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _primaryBrown : Colors.grey.shade600)),
        ],
      ),
    );
  }
}
