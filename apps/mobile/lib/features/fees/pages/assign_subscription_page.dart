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
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
              padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 0),
              child: ShimmerLoader.planList(),
            )
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  color: AppColors.brandAccent,
                  onRefresh: _loadPlans,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 28.r),
                    children: [
                      _memberHeader(),
                      SizedBox(height: 24.r),
                      Text(
                        'Assign a plan',
                        style: TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 21.r,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.r),
                      Text(
                        'Choose the plan to activate for this member.',
                        style:
                            TextStyle(color: Color(0xFF777777), fontSize: 12.r),
                      ),
                      SizedBox(height: 16.r),
                      if (_plans.isEmpty)
                        _emptyPlans()
                      else
                        ..._plans.map(_planRow),
                      SizedBox(height: 18.r),
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
            radius: 25.r,
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
        SizedBox(width: 12.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.brandDark,
                  fontSize: 16.r,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3.r),
              Text(
                'Assisted subscription assignment',
                style: TextStyle(color: Color(0xFF777777), fontSize: 11.r),
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
      padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 5.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E5),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.brandAccent,
          fontSize: 9.r,
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
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 8.r),
        padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 14.r),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF9F3) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.brandAccent : const Color(0xFFE7E7E7),
            width: selected ? 1.4.r : 1.r,
          ),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Iconsax.tick_circle5 : Iconsax.radio,
              size: 19.r,
              color: selected ? AppColors.brandAccent : const Color(0xFFB5B5B5),
            ),
            SizedBox(width: 10.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan['name']?.toString() ?? 'Plan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 14.r,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3.r),
                  Text(
                    '$duration days${description == null ? '' : ' · $description'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFF777777), fontSize: 11.r),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.r),
            Text(
              _money(amount),
              style: TextStyle(
                color: AppColors.brandDark,
                fontSize: 14.r,
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
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F3),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFFFE4CB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 17.r, color: AppColors.brandAccent),
          SizedBox(width: 9.r),
          Expanded(
            child: Text(
              'This activates the selected plan immediately. Payment posting and receipt generation remain part of the normal payment flow.',
              style: TextStyle(
                  color: Color(0xFF777777), fontSize: 11.r, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPlans() {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          Icon(Iconsax.card_remove, size: 30.r, color: Color(0xFF999999)),
          SizedBox(height: 8.r),
          Text(
            'No active plans are available right now.',
            style: TextStyle(color: Color(0xFF777777), fontSize: 12.r),
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
        padding: EdgeInsets.fromLTRB(16.r, 10.r, 16.r, 14.r),
        child: SizedBox(
          height: 48.r,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? SizedBox(
                    width: 16.r,
                    height: 16.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.r,
                      color: Colors.white,
                    ),
                  )
                : Icon(Iconsax.tick_circle, size: 18.r),
            label: Text(
              _isSubmitting
                  ? 'Assigning…'
                  : 'Assign ${plan['name'] ?? 'plan'} · ${_money(amount)}',
              style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9.r),
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
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.cloud_cross, size: 36.r, color: Color(0xFF777777)),
            SizedBox(height: 12.r),
            Text(
              _error ?? 'Could not load plans.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777777), fontSize: 12.r),
            ),
            SizedBox(height: 14.r),
            OutlinedButton.icon(
              onPressed: _loadPlans,
              icon: Icon(Iconsax.refresh, size: 16.r),
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
