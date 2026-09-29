import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../branch/models/member_model.dart';
import '../../organization/controllers/organization_repository.dart';

class AssignSubscriptionPage extends StatefulWidget {
  final MemberModel member;

  const AssignSubscriptionPage({super.key, required this.member});

  @override
  State<AssignSubscriptionPage> createState() => _AssignSubscriptionPageState();
}

class _AssignSubscriptionPageState extends State<AssignSubscriptionPage> {
  String? _selectedPlanId;
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId;
      final branchId = prefs.activeBranchId;
      if (orgId == null || branchId == null) {
        throw Exception('Select an active branch before assigning a plan.');
      }
      final response =
          await context.read<OrganizationRepository>().getOrganizationPlans(
        orgId,
        branchId: branchId,
        onFresh: (freshPlans) {
          if (!mounted) return;
          final activePlans =
              freshPlans.where((plan) => plan['is_active'] != false).toList();
          setState(() {
            _plans = activePlans;
            if (_selectedPlanId == null ||
                !_plans
                    .any((plan) => plan['id']?.toString() == _selectedPlanId)) {
              _selectedPlanId =
                  _plans.isEmpty ? null : _plans.first['id']?.toString();
            }
          });
        },
      );
      final plans =
          response.where((plan) => plan['is_active'] != false).toList();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        if (_selectedPlanId == null ||
            !_plans.any((plan) => plan['id']?.toString() == _selectedPlanId)) {
          _selectedPlanId =
              _plans.isEmpty ? null : _plans.first['id']?.toString();
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isLoading && _error == null && _selectedPlanId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => Navigator.maybePop(context),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh plans',
          ),
        ],
        onMenuSelected: (_) => _loadPlans(),
      ),
      bottomNavigationBar: canSubmit ? _submitBar() : null,
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ShimmerLoader.planList(),
            )
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  color: AppColors.brandAccent,
                  onRefresh: _loadPlans,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _memberHeader(),
                      const SizedBox(height: 24),
                      const Text(
                        'Assign a plan',
                        style: TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose the plan to activate for this member.',
                        style:
                            TextStyle(color: Color(0xFF777777), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      if (_plans.isEmpty)
                        _emptyPlans()
                      else
                        ..._plans.map(_planRow),
                      const SizedBox(height: 18),
                      _infoNote(),
                    ],
                  ),
                ),
    );
  }

  Widget _memberHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => showDailioMemberProfileSheet(
            context,
            DailioMemberPreview(
              memberId: widget.member.id,
              name: widget.member.name,
              role: widget.member.role?.name ?? 'Member',
              status: widget.member.status,
              avatarUrl: widget.member.avatarUrl,
              phone: widget.member.phone,
              email: widget.member.email,
              membershipNumber: widget.member.membershipNumber,
              subscriptionLabel: widget.member.activeSubscription?.planName,
            ),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFF2F2F2),
            backgroundImage: widget.member.avatarUrl == null
                ? null
                : NetworkImage(widget.member.avatarUrl!),
            child: widget.member.avatarUrl == null
                ? Text(
                    widget.member.name.isEmpty
                        ? '?'
                        : widget.member.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.brandDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Assisted subscription assignment',
                style: TextStyle(color: Color(0xFF777777), fontSize: 11),
              ),
            ],
          ),
        ),
        _badge('STAFF FLOW'),
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.brandAccent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _planRow(Map<String, dynamic> plan) {
    final id = plan['id']?.toString() ?? '';
    final selected = _selectedPlanId == id;
    final amount = (plan['amount_minor_unit'] as num?)?.toInt() ??
        (plan['amountMinorUnit'] as num?)?.toInt() ??
        0;
    final duration = (plan['duration_days'] as num?)?.toInt() ??
        (plan['durationDays'] as num?)?.toInt() ??
        0;
    final description = plan['description']?.toString();
    return InkWell(
      onTap: () => setState(() {
        _selectedPlanId = id;
        _idempotencyKey = null;
      }),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF9F3) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.brandAccent : const Color(0xFFE7E7E7),
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Iconsax.tick_circle5 : Iconsax.radio,
              size: 19,
              color: selected ? AppColors.brandAccent : const Color(0xFFB5B5B5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan['name']?.toString() ?? 'Plan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$duration days${description == null ? '' : ' · $description'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF777777), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _money(amount),
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE4CB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 17, color: AppColors.brandAccent),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'This activates the selected plan immediately. Payment posting and receipt generation remain part of the normal payment flow.',
              style: TextStyle(
                  color: Color(0xFF777777), fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPlans() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        children: [
          Icon(Iconsax.card_remove, size: 30, color: Color(0xFF999999)),
          SizedBox(height: 8),
          Text(
            'No active plans are available right now.',
            style: TextStyle(color: Color(0xFF777777), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    final plan = _plans.firstWhere(
      (item) => item['id']?.toString() == _selectedPlanId,
      orElse: () => <String, dynamic>{},
    );
    final amount = (plan['amount_minor_unit'] as num?)?.toInt() ??
        (plan['amountMinorUnit'] as num?)?.toInt() ??
        0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Iconsax.tick_circle, size: 18),
            label: Text(
              _isSubmitting
                  ? 'Assigning…'
                  : 'Assign ${plan['name'] ?? 'plan'} · ${_money(amount)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.cloud_cross, size: 36, color: Color(0xFF777777)),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not load plans.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadPlans,
              icon: const Icon(Iconsax.refresh, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final planId = _selectedPlanId;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (planId == null || branchId == null) return;
    setState(() => _isSubmitting = true);
    try {
      _idempotencyKey ??=
          'mobile-${widget.member.id}-$planId-${DateTime.now().toUtc().toIso8601String()}';
      await context.read<ApiClient>().dio.post(
            '/branches/$branchId/members/${widget.member.id}/subscriptions',
            data: {
              'plan_id': planId,
              'start_date': DateTime.now().toUtc().toIso8601String(),
            },
            options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription assigned')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not assign subscription: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _money(int minor) => 'INR ${(minor / 100).toStringAsFixed(0)}';
}
