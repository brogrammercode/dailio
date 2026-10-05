import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../auth/controllers/auth_cubit.dart';
import '../../auth/controllers/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../attendance/controllers/streak_repository.dart';
import '../../../core/widgets/dailio_streak_card.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _orgData;
  bool _isLoadingOrg = true;
  Future<Map<String, dynamic>>? _streakFuture;
  String? _streakBranchId;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesStorage>();
    final branchId = prefs.activeBranchId;
    if (branchId != null) {
      _streakBranchId = branchId;
      _streakFuture = _loadStreak(branchId);
    }
    _loadOrgData();
  }

  Future<void> _loadOrgData() async {
    final prefs = context.read<PreferencesStorage>();
    final orgId = prefs.activeOrganizationId;
    if (orgId == null) {
      if (mounted) setState(() => _isLoadingOrg = false);
      return;
    }
    final repository = context.read<OrganizationRepository>();
    try {
      // Read the organization directly so a type change made from this
      // device cannot be masked by an older cached memberships response.
      final organization = await repository.refreshOrganizationById(orgId);
      Map<String, dynamic>? membershipEntry;
      try {
        final organizations = await repository.getMyOrganizations();
        final organizationEntry = organizations
            .where((entry) => entry['organization']?['id'] == orgId)
            .firstOrNull;
        final memberships = organizationEntry?['location_memberships'];
        if (memberships is List && prefs.activeBranchId != null) {
          for (final rawMembership in memberships) {
            if (rawMembership is! Map) continue;
            final location = rawMembership['location'];
            if (location is Map &&
                location['id']?.toString() == prefs.activeBranchId) {
              membershipEntry = Map<String, dynamic>.from(rawMembership);
              break;
            }
          }
        }
      } catch (_) {
        // The direct organization response is still enough to render the
        // page if the memberships read is temporarily unavailable.
      }
      final branchId = prefs.activeBranchId;
      if (branchId != null) {
        final location = membershipEntry?['location'];
        final role = membershipEntry?['role'];
        final roleMap = role is Map ? Map<String, dynamic>.from(role) : null;
        final rawPermissions = membershipEntry?['effective_permissions'] ??
            roleMap?['permissions'];
        final permissions = rawPermissions is List
            ? rawPermissions.map((permission) => permission.toString()).toList()
            : prefs.activePermissions;
        await prefs.setActiveContext(
          organizationId: orgId,
          branchId: branchId,
          organizationName: organization['name']?.toString(),
          organizationType: organization['type']?.toString(),
          branchName: location is Map
              ? location['name']?.toString()
              : prefs.activeBranchName,
          branchTimezone: location is Map
              ? location['timezone']?.toString()
              : prefs.activeBranchTimezone,
          roleSystemKey:
              roleMap?['system_key']?.toString() ?? prefs.activeRoleSystemKey,
          permissions: permissions,
        );
      }
      if (mounted) {
        setState(() {
          _orgData = {'organization': organization};
          _isLoadingOrg = false;
        });
      }
    } catch (_) {
      // Keep the screen usable if the direct organization read is denied or
      // temporarily unavailable; the memberships response is still a valid
      // fallback for the organization card and feature flags.
      try {
        final orgs = await repository.getMyOrganizations();
        final match =
            orgs.where((m) => m['organization']?['id'] == orgId).firstOrNull;
        final fallbackOrg = match?['organization'];
        if (fallbackOrg is Map && prefs.activeBranchId != null) {
          final memberships = match?['location_memberships'];
          Map<String, dynamic>? activeMembership;
          if (memberships is List) {
            for (final rawMembership in memberships) {
              if (rawMembership is! Map) continue;
              final location = rawMembership['location'];
              if (location is Map &&
                  location['id']?.toString() == prefs.activeBranchId) {
                activeMembership = Map<String, dynamic>.from(rawMembership);
                break;
              }
            }
          }
          final role = activeMembership?['role'];
          final roleMap = role is Map ? Map<String, dynamic>.from(role) : null;
          final rawPermissions = activeMembership?['effective_permissions'] ??
              roleMap?['permissions'];
          await prefs.setActiveContext(
            organizationId: orgId,
            branchId: prefs.activeBranchId!,
            organizationName: fallbackOrg['name']?.toString(),
            organizationType: fallbackOrg['type']?.toString(),
            branchName: prefs.activeBranchName,
            branchTimezone: prefs.activeBranchTimezone,
            roleSystemKey:
                roleMap?['system_key']?.toString() ?? prefs.activeRoleSystemKey,
            permissions: rawPermissions is List
                ? rawPermissions
                    .map((permission) => permission.toString())
                    .toList()
                : prefs.activePermissions,
          );
        }
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
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'This will end your active sessions on this device.',
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Iconsax.logout,
    );
    if (confirmed == true && mounted) {
      await context.read<PreferencesStorage>().clearContext();
      if (!mounted) return;
      await context.read<AuthCubit>().signOut();
    }
  }

  Future<void> _openFacingIssue() async {
    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '916204254184',
      queryParameters: const {
        'text': 'Hi Harsh, I am facing issue in ...',
      },
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('WhatsApp is not available on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final prefs = context.watch<PreferencesStorage>();
        _ensureStreakFuture(prefs);
        final orgName = prefs.activeOrganizationName;
        final branchName = prefs.activeBranchName;
        final orgMap = _orgData?['organization'] as Map<String, dynamic>?;
        final organizationType =
            (orgMap?['type']?.toString() ?? prefs.activeOrganizationType ?? '')
                .trim()
                .toUpperCase();
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
          appBar: DailioSimpleAppBar(
            menuItems: const [
              DailioMenuItem(
                value: 'refresh',
                icon: Iconsax.refresh,
                label: 'Refresh',
              ),
              DailioMenuItem(
                value: 'sign_out',
                icon: Iconsax.logout,
                label: 'Sign out',
                destructive: true,
              ),
            ],
            onMenuSelected: (value) {
              if (value == 'refresh') _refreshPage();
              if (value == 'sign_out') _confirmSignOut();
            },
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.brandAccent,
              onRefresh: _refreshPage,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 100.r),
                children: [
                  //  Context Pill
                  _buildContextPill(orgName, branchName),
                  SizedBox(height: 16.r),

                  //  Profile Card
                  _buildProfileCard(context, user, prefs),
                  if (_streakFuture != null)
                    DailioStreakCard(
                      future: _streakFuture!,
                    ),
                  SizedBox(height: 16.r),

                  //  Organization Card
                  _buildOrgCard(context, orgMap, orgName,
                      canEdit: prefs.hasPermission('GYM_UPDATE')),
                  SizedBox(height: 24.r),

                  //  Management Modules
                  _sectionHeader('MANAGEMENT & OPERATIONS', 'Workspace tools'),
                  SizedBox(height: 12.r),

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

                  if (prefs.hasPermission('LEAVE_READ_SELF') ||
                      prefs.hasPermission('LEAVE_READ_ALL') ||
                      prefs.hasPermission('LEAVE_MANAGE') ||
                      prefs.hasPermission('HOLIDAY_READ') ||
                      prefs.hasPermission('HOLIDAY_MANAGE'))
                    _buildModuleCard(
                      icon: Iconsax.calendar,
                      iconColor: Colors.orange,
                      iconBg: Colors.orange.shade50,
                      title: 'Leaves & Holidays',
                      subtitle: 'Branch calendar and leave requests',
                      actionLabel: 'Open',
                      onTap: () => context.push(AppRoutes.leavesHolidays),
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

                  if (organizationType == 'FOOD_SERVICE' &&
                      (prefs.hasPermission('MEAL_SERVE') ||
                          prefs.hasPermission('MEAL_MANAGE')))
                    _buildModuleCard(
                      icon: Iconsax.cup,
                      title: 'Meals',
                      subtitle: 'Breakfast, lunch, dinner & serving history',
                      actionLabel: 'Open',
                      onTap: () => context.push(AppRoutes.meals),
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

                  _buildModuleCard(
                    icon: Iconsax.message_question,
                    iconColor: AppColors.brandAccent,
                    iconBg: AppColors.brandAccent.withValues(alpha: 0.10),
                    title: 'Facing an issue?',
                    subtitle: 'Talk to Harsh on WhatsApp with evidence',
                    actionLabel: 'Contact',
                    onTap: _openFacingIssue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _ensureStreakFuture(PreferencesStorage prefs) {
    final branchId = prefs.activeBranchId;
    if (branchId == null || branchId == _streakBranchId) return;
    _streakBranchId = branchId;
    _streakFuture = _loadStreak(branchId);
  }

  Future<void> _refreshPage() async {
    await Future.wait([
      _loadOrgData(),
      _refreshStreak(),
    ]);
  }

  Future<void> _refreshStreak() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) return;
    if (mounted) {
      setState(() {
        _streakBranchId = branchId;
        _streakFuture = _loadStreak(branchId);
      });
    }
    await _streakFuture;
  }

  Future<Map<String, dynamic>> _loadStreak(String branchId) {
    return context.read<StreakRepository>().getMyStreak(
      branchId,
      onFresh: (fresh) {
        if (!mounted || _streakBranchId != branchId) return;
        setState(
            () => _streakFuture = Future<Map<String, dynamic>>.value(fresh));
      },
    );
  }

  //  Context Pill
  Widget _buildContextPill(String? orgName, String? branchName) {
    if (orgName == null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Iconsax.info_circle,
                size: 16.r, color: Colors.orange.shade700),
            SizedBox(width: 8.r),
            Expanded(
              child: Text(
                'No active branch selected. Tap to choose a workspace.',
                style: TextStyle(fontSize: 12.r, color: Colors.orange),
              ),
            ),
            Icon(Iconsax.arrow_right_3,
                size: 14.r, color: Colors.orange.shade700),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push(AppRoutes.contextSwitcher),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Iconsax.building_3, size: 16.r, color: Colors.orange),
            SizedBox(width: 8.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orgName,
                    style:
                        TextStyle(fontSize: 12.r, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (branchName != null)
                    Text(
                      branchName,
                      style: TextStyle(fontSize: 10.r, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.r, backgroundColor: Colors.green),
                  SizedBox(width: 4.r),
                  Text('Live',
                      style: TextStyle(
                          fontSize: 10.r,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(width: 8.r),
            Icon(Iconsax.arrow_swap_horizontal,
                size: 14.r, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  //  Profile Card
  Widget _buildProfileCard(
      BuildContext context, UserModel? user, PreferencesStorage prefs) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.r),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 23.r,
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
          SizedBox(width: 12.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Loading...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 14.r,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.r),
                Text(
                  user?.email ??
                      '${prefs.activeRoleSystemKey ?? 'Member'} · Verified sign-in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 11.r,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 4.r),
            decoration: BoxDecoration(
              color: AppColors.brandAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5.r),
            ),
            child: Text(
              prefs.activeRoleSystemKey ?? 'Member',
              style: TextStyle(
                color: AppColors.brandAccent,
                fontSize: 9.r,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => context.push(AppRoutes.profile),
            icon: Icon(Iconsax.edit_2, size: 18.r),
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
      padding: EdgeInsets.symmetric(vertical: 10.r),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: AppColors.brandAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.building_3,
                color: AppColors.brandAccent, size: 19.r),
          ),
          SizedBox(width: 12.r),
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
                  style: TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 14.r,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.r),
                Text(
                  _isLoadingOrg
                      ? 'Loading organization details'
                      : (orgMap?['website'] ??
                          orgMap?['industry'] ??
                          'No website configured'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 11.r,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Edit organization',
              onPressed: () async {
                await context.push(AppRoutes.editOrganization);
                if (mounted) await _loadOrgData();
              },
              icon: Icon(Iconsax.setting_4, size: 18.r),
              color: AppColors.brandDark,
              visualDensity: VisualDensity.compact,
            )
          else
            Icon(Iconsax.arrow_right_3, size: 16.r, color: Color(0xFF9E9E9E)),
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
      margin: EdgeInsets.only(bottom: 8.r),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.fromLTRB(4.r, 10.r, 4.r, 12.r),
          child: Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: iconBg ?? const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20.r),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 13.r,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3.r),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 11.r,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.r),
              Text(
                actionLabel,
                style: TextStyle(
                  color: AppColors.brandAccent,
                  fontSize: 10.r,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 6.r),
              Icon(Iconsax.arrow_right_3, size: 16.r, color: Color(0xFF9E9E9E)),
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
            style: TextStyle(
                fontSize: 10.r,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5.r)),
        if (badge != null) ...[
          SizedBox(width: 8.r),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 3.r),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 10.r,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
