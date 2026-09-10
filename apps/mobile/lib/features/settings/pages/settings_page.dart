import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
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

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SafeArea(
            child: RefreshIndicator(
              color: Colors.orange.shade800,
              onRefresh: _loadOrgData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                children: [
                  // ── Context Pill ───────────────────────────────────────
                  _buildContextPill(orgName, branchName),
                  const SizedBox(height: 16),

                  // ── Profile Card ───────────────────────────────────────
                  _buildProfileCard(context, user),
                  const SizedBox(height: 16),

                  // ── Organization Card ──────────────────────────────────
                  _buildOrgCard(context, orgMap, orgName),
                  const SizedBox(height: 24),

                  // ── Management Modules ─────────────────────────────────
                  _sectionHeader('MANAGEMENT & OPERATIONS', '6 Modules'),
                  const SizedBox(height: 12),

                  _buildModuleCard(
                    icon: Iconsax.lock,
                    title: 'Roles & Permissions',
                    subtitle: 'Configure RBAC roles & access levels',
                    actionLabel: 'Configure',
                    onTap: () => context.push(AppRoutes.roles),
                    chips: const ['Owner', 'Branch Mgr', 'Trainer'],
                    primaryChipIndex: 0,
                  ),

                  _buildModuleCard(
                    icon: Iconsax.personalcard,
                    iconColor: Colors.orange,
                    iconBg: Colors.orange.shade50,
                    title: 'Members & Admissions',
                    subtitle: 'Manage enrolled members & join requests',
                    actionLabel: 'Manage',
                    isPrimaryAction: true,
                    onTap: () => context.push(AppRoutes.members),
                    chips: const ['Active', 'Pending Requests', 'Suspended'],
                    primaryChipIndex: 0,
                  ),

                  _buildModuleCard(
                    icon: Iconsax.hierarchy,
                    title: 'Branch Locations',
                    subtitle: 'Manage your gym branches & facilities',
                    actionLabel: 'Manage',
                    onTap: () => context.push(AppRoutes.createBranch),
                    chips: const ['Primary Branch', 'Add Branch'],
                    primaryChipIndex: 0,
                  ),

                  _buildModuleCard(
                    icon: Iconsax.card,
                    title: 'Subscription Plans',
                    subtitle: 'Membership tiers, pricing & billing',
                    actionLabel: 'Configure',
                    onTap: () => context.push(AppRoutes.subscriptionPlans),
                    chips: const [
                      'Annual Elite',
                      'Quarterly Pro',
                      'Monthly Flex'
                    ],
                    primaryChipIndex: 0,
                  ),

                  _buildModuleCard(
                    icon: Iconsax.clock,
                    title: 'Shift Configuration',
                    subtitle: 'Rosters, grace periods & duty cycles',
                    actionLabel: 'Configure',
                    onTap: () => context.push(AppRoutes.shiftManagement),
                    chips: const ['Morning', 'Evening', 'General Duty'],
                    primaryChipIndex: 0,
                  ),

                  _buildModuleCard(
                    icon: Iconsax.wallet_2,
                    iconColor: Colors.orange,
                    iconBg: Colors.orange.shade50,
                    title: 'Payroll & Compensation',
                    subtitle: 'Staff salary structures & disbursals',
                    actionLabel: 'Manage',
                    isPrimaryAction: true,
                    onTap: () => context.push(AppRoutes.payrollManagement),
                    chips: const [
                      'Monthly Payouts',
                      'Base + Incentive',
                      'Tax & Deductions'
                    ],
                    primaryChipIndex: 0,
                  ),

                  const SizedBox(height: 24),

                  // ── Workspace Settings ──────────────────────────────────
                  _sectionHeader('WORKSPACE SETTINGS', null),
                  const SizedBox(height: 12),
                  _buildWorkspaceCard(),

                  const SizedBox(height: 24),

                  // ── Sign Out ────────────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: _confirmSignOut,
                    icon:
                        const Icon(Iconsax.logout, color: Colors.red, size: 18),
                    label: Text(
                      orgName != null ? 'Sign Out of $orgName' : 'Sign Out',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red.shade50,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to confirm — this will end all active kiosk sessions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Context Pill ───────────────────────────────────────────────────────────
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

  // ─── Profile Card ───────────────────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.orange.shade100,
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? Text(
                        (user?.name.isNotEmpty == true)
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Name + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user?.name ?? 'Loading...',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.profile),
                          icon: const Icon(Iconsax.edit, size: 12),
                          label: const Text('Edit',
                              style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 0),
                            minimumSize: const Size(0, 28),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.shield_tick,
                              size: 10, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('Owner',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (user?.email != null)
                      Text(
                        user!.email!,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (user == null)
                      Text('Not signed in',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Access row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.shield_security,
                    color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('ACCESS',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      Text('Organization Owner',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                const SizedBox(width: 12),
                const Icon(Iconsax.security_safe,
                    color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('GOOGLE',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      Text('Verified Sign-in',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Organization Card ──────────────────────────────────────────────────────
  Widget _buildOrgCard(
      BuildContext context, Map<String, dynamic>? orgMap, String? orgName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Iconsax.weight, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.verify,
                            color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _isLoadingOrg
                                ? 'Loading...'
                                : (orgMap?['name'] ??
                                    orgName ??
                                    'Your Organization'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (orgMap?['website'] != null || orgMap?['slug'] != null)
                      Text(
                        orgMap?['website'] ??
                            'dailio.app/${orgMap?['slug'] ?? ''}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        _isLoadingOrg ? '' : 'No website configured',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.editOrganization),
                icon: const Icon(Iconsax.setting_4, size: 12),
                label: const Text('Edit', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          if (_isLoadingOrg) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: Colors.orange, minHeight: 2),
          ] else if (orgMap != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 4, backgroundColor: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      orgMap['industry'] ?? 'Fitness & Wellness',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Active',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.info_circle,
                      size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Organization details unavailable. Check your connection.',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Module Card ────────────────────────────────────────────────────────────
  Widget _buildModuleCard({
    required IconData icon,
    Color iconColor = Colors.black54,
    Color? iconBg,
    required String title,
    required String subtitle,
    required String actionLabel,
    bool isPrimaryAction = false,
    required VoidCallback onTap,
    required List<String> chips,
    required int primaryChipIndex,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBg ?? const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  isPrimaryAction
                      ? ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(actionLabel,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      : OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            side: BorderSide(color: Colors.grey.shade300),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(actionLabel,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black87)),
                        ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(chips.length, (i) {
                    final isPrimary = i == primaryChipIndex;
                    return Padding(
                      padding:
                          EdgeInsets.only(right: i < chips.length - 1 ? 6 : 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? Colors.orange.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPrimary
                                ? Colors.orange.shade200
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          chips[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPrimary
                                ? Colors.orange.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Workspace Settings Card ────────────────────────────────────────────────
  Widget _buildWorkspaceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSettingsRow(
            icon: Iconsax.notification_bing,
            title: 'Push & Shift Alerts',
            subtitle: 'Real-time attendance & gym floor pings',
          ),
          const Divider(height: 24),
          _buildSettingsRow(
            icon: Iconsax.scan,
            title: 'Biometric Check-ins',
            subtitle: 'Selfie & geofence enforcement on punch',
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Iconsax.document_code, size: 18, color: Colors.grey),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App Version',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('v2.4.1 (Build 4182)',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Up to date',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        Icon(Iconsax.arrow_right_3, size: 14, color: Colors.grey.shade400),
      ],
    );
  }

  // ─── Section Header ─────────────────────────────────────────────────────────
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
