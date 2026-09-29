import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/members_repository.dart';
import '../models/member_model.dart';

class MemberDetailPage extends StatefulWidget {
  final String membershipId;

  const MemberDetailPage({super.key, required this.membershipId});

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late final MembersRepository _repository;
  late final PreferencesStorage _preferences;
  late final String _branchId;

  MemberModel? _member;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MembersRepository>();
    _preferences = context.read<PreferencesStorage>();
    _branchId = _preferences.activeBranchId!;
    _loadMember();
  }

  Future<void> _loadMember() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final result = await _repository.getMember(
        _branchId,
        widget.membershipId,
        onFresh: (freshData) {
          final rawFresh = freshData['member'];
          if (!mounted || rawFresh is! Map) return;
          setState(() => _member = MemberModel.fromJson(
                Map<String, dynamic>.from(rawFresh),
              ));
        },
      );
      final raw = result['member'];
      if (raw is! Map) throw Exception('Member data was not returned');
      if (mounted) {
        setState(() => _member = MemberModel.fromJson(
              Map<String, dynamic>.from(raw),
            ));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performAction(String action) async {
    final isSuspend = action == 'suspend';
    final reason = await showReasonDialog(
      context,
      title: isSuspend ? 'Suspend member' : 'Deactivate member',
      message: 'Add a reason so this change is clear in the member history.',
      confirmLabel: isSuspend ? 'Suspend' : 'Deactivate',
      isDestructive: true,
      icon: isSuspend ? Iconsax.pause_circle : Iconsax.user_remove,
    );
    if (reason == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      if (isSuspend) {
        await _repository.suspendMember(_branchId, widget.membershipId, reason);
      } else {
        await _repository.deactivateMember(
            _branchId, widget.membershipId, reason);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isSuspend ? 'Member suspended' : 'Member deactivated'),
          ),
        );
      }
      await _loadMember();
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update member: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = _member;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => Navigator.maybePop(context),
        menuItems: [
          const DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh member',
          ),
          if (_preferences.hasPermission('MEMBER_SUSPEND') &&
              member?.status == 'ACTIVE')
            const DailioMenuItem(
              value: 'suspend',
              icon: Iconsax.pause_circle,
              label: 'Suspend member',
            ),
          if (_preferences.hasPermission('MEMBER_DEACTIVATE') &&
              member?.status != 'INACTIVE')
            const DailioMenuItem(
              value: 'deactivate',
              icon: Iconsax.user_remove,
              label: 'Deactivate member',
              destructive: true,
            ),
        ],
        onMenuSelected: (value) {
          if (value == 'refresh') _loadMember();
          if (value == 'suspend' || value == 'deactivate') {
            _performAction(value);
          }
        },
      ),
      body: _isLoading
          ? ShimmerLoader.detailPage()
          : _error != null
              ? _errorState()
              : member == null
                  ? _emptyState()
                  : _buildContent(member),
    );
  }

  Widget _buildContent(MemberModel member) {
    return RefreshIndicator(
      onRefresh: _loadMember,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _profileHeader(member),
          const SizedBox(height: 22),
          _sectionLabel('Subscription'),
          const SizedBox(height: 8),
          _subscriptionSection(member),
          const SizedBox(height: 22),
          _sectionLabel('Member details'),
          const SizedBox(height: 8),
          _detailsSection(member),
          const SizedBox(height: 22),
          _sectionLabel('Roles'),
          const SizedBox(height: 8),
          _rolesSection(member),
          const SizedBox(height: 22),
          _sectionLabel('Access and operations'),
          const SizedBox(height: 8),
          _operationsSection(member),
        ],
      ),
    );
  }

  Widget _profileHeader(MemberModel member) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showDailioMemberProfileSheet(
            context,
            DailioMemberPreview(
              memberId: member.id,
              name: member.name,
              role: member.role?.name ?? 'Member',
              status: member.status,
              avatarUrl: member.avatarUrl,
              phone: member.phone,
              email: member.email,
              membershipNumber: member.membershipNumber,
              subscriptionLabel: member.activeSubscription?.planName,
            ),
          ),
          child: _avatar(member, radius: 29),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.brandDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _badge(member.role?.name ?? 'Member', AppColors.brandAccent),
                  _badge(_pretty(member.status), _statusColor(member.status)),
                ],
              ),
              if (member.email?.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  member.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _subscriptionSection(MemberModel member) {
    if (member.subscriptions.isEmpty) {
      return _outlinedBox(
        child: _emptyLine(Iconsax.card_remove, 'No subscription history'),
      );
    }
    return _outlinedBox(
      child: Column(
        children: [
          for (var index = 0; index < member.subscriptions.length; index++) ...[
            _subscriptionRow(member.subscriptions[index], index == 0),
            if (index != member.subscriptions.length - 1)
              const Divider(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _subscriptionRow(MemberSubscription subscription, bool isCurrent) {
    final statusColor = _statusColor(subscription.status);
    final amount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(subscription.amountMinor / 100);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isCurrent ? Iconsax.tick_circle : Iconsax.card,
          size: 19,
          color: statusColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subscription.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _badge(_pretty(subscription.status), statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM yyyy').format(subscription.startDate.toLocal())} – ${DateFormat('dd MMM yyyy').format(subscription.endDate.toLocal())} · $amount',
                style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailsSection(MemberModel member) {
    return _outlinedBox(
      child: Column(
        children: [
          _detailRow(
              Iconsax.personalcard,
              'Member ID',
              member.membershipNumber.isEmpty
                  ? 'Not assigned'
                  : member.membershipNumber),
          _detailRow(
              Iconsax.calendar_1, 'Joined', _formatDate(member.joinedAt)),
          _detailRow(Iconsax.call, 'Phone', _value(member.phone)),
          _detailRow(Iconsax.sms, 'Email', _value(member.email)),
        ],
      ),
    );
  }

  Widget _rolesSection(MemberModel member) {
    final roles = <String>{
      if (member.role != null) member.role!.name,
      ...member.assignedRoles.map((role) => role.name),
    }.toList();
    return _outlinedBox(
      child: roles.isEmpty
          ? _emptyLine(Iconsax.security_user, 'No roles assigned')
          : Wrap(
              spacing: 7,
              runSpacing: 7,
              children: roles
                  .map((role) => _badge(role, AppColors.brandAccent))
                  .toList(),
            ),
    );
  }

  Widget _operationsSection(MemberModel member) {
    return _outlinedBox(
      child: Column(
        children: [
          _detailRow(Iconsax.clock, 'Shift',
              member.shiftId == null ? 'Not assigned' : 'Assigned'),
          _detailRow(Iconsax.user_octagon, 'Manager',
              member.managerMemberId == null ? 'Not assigned' : 'Assigned'),
          _detailRow(Iconsax.wallet_3, 'Salary structure',
              member.salaryStructureId == null ? 'Not assigned' : 'Assigned'),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.brandAccent),
          const SizedBox(width: 9),
          SizedBox(
            width: 106,
            child: Text(label,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E2DC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _emptyLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF999999)),
        const SizedBox(width: 9),
        Text(text,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 12)),
      ],
    );
  }

  Widget _avatar(MemberModel member, {double radius = 25}) {
    final hasImage = member.avatarUrl?.isNotEmpty == true;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brandAccent.withValues(alpha: 0.12),
      backgroundImage: hasImage ? NetworkImage(member.avatarUrl!) : null,
      child: hasImage
          ? null
          : Text(
              member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
              style: TextStyle(
                color: AppColors.brandAccent,
                fontSize: radius * .62,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.brandDark,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.warning_2, color: AppColors.error, size: 30),
            const SizedBox(height: 10),
            const Text('Unable to load member details'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadMember,
              icon: const Icon(Iconsax.refresh, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => const Center(child: Text('Member not found'));

  String _value(String? value) =>
      value?.trim().isNotEmpty == true ? value! : 'Not available';

  String _formatDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    return date == null
        ? 'Not available'
        : DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.success;
      case 'SUSPENDED':
        return AppColors.warning;
      case 'INACTIVE':
      case 'DEACTIVATED':
        return AppColors.error;
      default:
        return AppColors.brandAccent;
    }
  }

  String _pretty(String value) {
    final normalized = value.replaceAll('_', ' ').toLowerCase();
    return normalized.isEmpty
        ? value
        : '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}
