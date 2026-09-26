import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../auth/controllers/auth_cubit.dart';
import '../../auth/controllers/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../organization/controllers/organization_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _orgData;
  bool _isLoadingOrg = true;

  @override
  void initState() {
    super.initState();
    _loadOrgData();
  }

  Future<void> _loadOrgData() async {
    final prefs = context.read<PreferencesStorage>();
    final orgId = prefs.activeOrganizationId;
    if (orgId == null) {
      if (mounted) setState(() => _isLoadingOrg = false);
      return;
    }
    try {
      final orgs =
          await context.read<OrganizationRepository>().getMyOrganizations();
      final match =
          orgs.where((m) => m['organization']?['id'] == orgId).firstOrNull;
      if (mounted) {
        setState(() {
          _orgData = match;
          _isLoadingOrg = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOrg = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'This will end all your active kiosk sessions on this device.'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthCubit>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final prefs = context.read<PreferencesStorage>();
        final orgName = prefs.activeOrganizationName;
        final branchName = prefs.activeBranchName;
        final orgMap = _orgData?['organization'] as Map<String, dynamic>?;
        final canReadRoles = prefs.hasPermission('ROLE_READ');
        final canReadMembers = prefs.hasPermission('MEMBER_READ_ALL');
        final canManageBranches = prefs.hasPermission('BRANCH_CREATE') ||
            prefs.hasPermission('BRANCH_UPDATE');
        // PLAN_READ powers member plan discovery; the settings card is the
        // administrative plan-management surface and must stay hidden from
        // members.
        final canReadPlans = prefs.hasPermission('PLAN_MANAGE');
        final canManagePlans = prefs.hasPermission('PLAN_MANAGE');
        final canManageShifts = prefs.hasPermission('SHIFT_MANAGE') ||
            prefs.hasPermission('SHIFT_READ_ALL');
        final canManagePayroll = prefs.hasPermission('PAYROLL_GENERATE') ||
            prefs.hasPermission('PAYROLL_READ_BRANCH');

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.brandDark,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Dailio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            actions: [
              DailioOverflowMenu<String>(
                items: const [
                  DailioMenuItem(
                    value: 'refresh',
                    icon: Icons.refresh,
                    label: 'Refresh',
                  ),
                  DailioMenuItem(
                    value: 'sign_out',
                    icon: Iconsax.logout,
                    label: 'Sign out',
                    destructive: true,
                  ),
                ],
                onSelected: (value) {
                  if (value == 'refresh') _loadOrgData();
                  if (value == 'sign_out') _confirmSignOut();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.brandAccent,
              onRefresh: _loadOrgData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  //  Context Pill
                  _buildContextPill(orgName, branchName),
                  const SizedBox(height: 16),

                  //  Profile Card
                  _buildProfileCard(context, user, prefs),
                  const SizedBox(height: 16),

                  //  Organization Card
                  _buildOrgCard(context, orgMap, orgName,
                      canEdit: prefs.hasPermission('GYM_UPDATE')),
                  const SizedBox(height: 24),

                  //  Management Modules
                  _sectionHeader('MANAGEMENT & OPERATIONS', '6 Modules'),
                  const SizedBox(height: 12),

                  if (canReadRoles)
                    _buildModuleCard(
                      icon: Iconsax.lock,
                      title: 'Roles & Permissions',
                      subtitle: 'Configure RBAC roles & access levels',
                      actionLabel: 'Configure',
                      onTap: () => context.push(AppRoutes.roles),
                    ),

                  if (canReadMembers)
                    _buildModuleCard(
                      icon: Iconsax.personalcard,
                      iconColor: Colors.orange,
                      iconBg: Colors.orange.shade50,
                      title: 'Members & Admissions',
                      subtitle: 'Manage enrolled members & join requests',
                      actionLabel: 'Manage',
                      onTap: () => context.push(AppRoutes.members),
                    ),

                  if (canManageBranches)
                    _buildModuleCard(
                      icon: Iconsax.hierarchy,
                      title: 'Branch Locations',
                      subtitle: 'Manage your gym branches & facilities',
                      actionLabel: 'Manage',
                      onTap: () => context.push(AppRoutes.manageBranches),
                    ),

                  if (canReadPlans)
                    _buildModuleCard(
                      icon: Iconsax.card,
                      title: 'Subscription Plans',
                      subtitle: 'Membership tiers, pricing & billing',
                      actionLabel: canManagePlans ? 'Configure' : 'View',
                      onTap: () => context.push(AppRoutes.subscriptionPlans),
                    ),

                  if (canManageShifts)
                    _buildModuleCard(
                      icon: Iconsax.clock,
                      title: 'Shift Configuration',
                      subtitle: 'Rosters, grace periods & duty cycles',
                      actionLabel: 'Configure',
                      onTap: () => context.push(AppRoutes.shiftManagement),
                    ),

                  if (canManagePayroll)
                    _buildModuleCard(
                      icon: Iconsax.wallet_2,
                      iconColor: Colors.orange,
                      iconBg: Colors.orange.shade50,
                      title: 'Payroll & Compensation',
                      subtitle: 'Staff salary structures & disbursals',
                      actionLabel: 'Manage',
                      onTap: () => context.push(AppRoutes.payrollManagement),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  //  Context Pill
  Widget _buildContextPill(String? orgName, String? branchName) {
    if (orgName == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Iconsax.info_circle, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No active branch selected. Tap to choose a workspace.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
            Icon(Iconsax.arrow_right_3,
                size: 14, color: Colors.orange.shade700),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push(AppRoutes.contextSwitcher),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.building_3, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orgName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (branchName != null)
                    Text(
                      branchName,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 3, backgroundColor: Colors.green),
                  const SizedBox(width: 4),
                  Text('Live',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Iconsax.arrow_swap_horizontal,
                size: 14, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  //  Profile Card
  Widget _buildProfileCard(
      BuildContext context, UserModel? user, PreferencesStorage prefs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.brandAccent.withValues(alpha: 0.12),
            backgroundImage:
                user?.avatarUrl == null ? null : NetworkImage(user!.avatarUrl!),
            child: user?.avatarUrl == null
                ? Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.brandAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Loading...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ??
                      '${prefs.activeRoleSystemKey ?? 'Member'} · Verified sign-in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              prefs.activeRoleSystemKey ?? 'Member',
              style: const TextStyle(
                color: AppColors.brandAccent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => context.push(AppRoutes.profile),
            icon: const Icon(Iconsax.edit_2, size: 18),
            color: AppColors.brandDark,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  //  Organization Card
  Widget _buildOrgCard(
      BuildContext context, Map<String, dynamic>? orgMap, String? orgName,
      {required bool canEdit}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.building_3,
                color: AppColors.brandAccent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingOrg
                      ? 'Loading...'
                      : (orgMap?['name'] ?? orgName ?? 'Your Organization'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isLoadingOrg
                      ? 'Loading organization details'
                      : (orgMap?['website'] ??
                          orgMap?['industry'] ??
                          'No website configured'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Edit organization',
              onPressed: () => context.push(AppRoutes.editOrganization),
              icon: const Icon(Iconsax.setting_4, size: 18),
              color: AppColors.brandDark,
              visualDensity: VisualDensity.compact,
            )
          else
            const Icon(Iconsax.arrow_right_3,
                size: 16, color: Color(0xFF9E9E9E)),
        ],
      ),
    );
  }

  //  Module Card
  Widget _buildModuleCard({
    required IconData icon,
    Color iconColor = Colors.black54,
    Color? iconBg,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg ?? const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                actionLabel,
                style: const TextStyle(
                  color: AppColors.brandAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Iconsax.arrow_right_3,
                  size: 16, color: Color(0xFF9E9E9E)),
            ],
          ),
        ),
      ),
    );
  }

  //  Section Header
  Widget _sectionHeader(String label, String? badge) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
