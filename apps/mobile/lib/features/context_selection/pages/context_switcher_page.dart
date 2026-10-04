import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../organization/controllers/organization_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ContextSwitcherPage extends StatefulWidget {
  const ContextSwitcherPage({super.key});

  @override
  State<ContextSwitcherPage> createState() => _ContextSwitcherPageState();
}

class _ContextSwitcherPageState extends State<ContextSwitcherPage> {
  late final OrganizationRepository _repository;
  List<Map<String, dynamic>> _memberships = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<OrganizationRepository>();
    _loadContexts();
  }

  Future<void> _loadContexts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _repository.getMyOrganizations();
      if (mounted) setState(() => _memberships = results);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your workspaces.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectContext(Map<String, dynamic> organization,
      Map<String, dynamic> membership) async {
    final prefs = context.read<PreferencesStorage>();
    final branch = Map<String, dynamic>.from(membership['location'] as Map);
    final role = (membership['role'] as Map?)?.cast<String, dynamic>();
    await prefs.setActiveContext(
      organizationId: organization['id'],
      branchId: branch['id'],
      organizationName: organization['name'],
      branchName: branch['name'],
      branchTimezone: branch['timezone']?.toString(),
      roleSystemKey: role?['system_key']?.toString(),
      permissions: (role?['permissions'] as List?)?.cast<String>(),
    );
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
              value: 'refresh', icon: Iconsax.refresh, label: 'Refresh'),
        ],
        onMenuSelected: (_) => _loadContexts(),
      ),
      body: SafeArea(
        child: _isLoading
            ? ShimmerLoader.settingsList()
            : _error != null
                ? DailioOnboardingEmpty(
                    icon: Iconsax.cloud_cross,
                    title: 'Could not load workspaces',
                    subtitle: _error!,
                    action: DailioOnboardingButton(
                      label: 'Try again',
                      icon: Iconsax.refresh,
                      onPressed: _loadContexts,
                    ),
                  )
                : _memberships.isEmpty
                    ? DailioOnboardingEmpty(
                        icon: Iconsax.building_4,
                        title: 'No workspace yet',
                        subtitle:
                            'Join an existing organization or create your own.',
                        action: DailioOnboardingButton(
                          label: 'Join or create',
                          onPressed: () => context.go(AppRoutes.joinOrCreate),
                        ),
                      )
                    : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.r, 18.r, 16.r, 32.r),
      children: [
        Text('Choose a workspace',
            style: TextStyle(fontSize: 22.r, fontWeight: FontWeight.w800)),
        SizedBox(height: 5.r),
        Text('Select the organization and branch you want to use.',
            style: TextStyle(fontSize: 13.r, color: Color(0xFF858585))),
        SizedBox(height: 22.r),
        ..._memberships.expand((membership) {
          final organization =
              Map<String, dynamic>.from(membership['organization'] as Map);
          final branches = (membership['location_memberships'] as List?) ?? [];
          return [
            DailioOnboardingSectionLabel(
                organization['name']?.toString() ?? 'Organization'),
            ...branches.asMap().entries.map((entry) {
              final item = Map<String, dynamic>.from(entry.value as Map);
              final branch = Map<String, dynamic>.from(item['location'] as Map);
              final role =
                  (item['role'] as Map?)?['name']?.toString() ?? 'Member';
              return Column(
                children: [
                  DailioOnboardingInfoRow(
                    icon: Iconsax.shop,
                    title: branch['name']?.toString() ?? 'Branch',
                    subtitle:
                        '${branch['address']?.toString() ?? 'No address'} · $role',
                    trailing: Icon(Iconsax.arrow_right_3,
                        size: 17.r, color: Color(0xFF9A9A9A)),
                    onTap: () => _selectContext(organization, item),
                  ),
                  if (entry.key != branches.length - 1) Divider(height: 1.r),
                ],
              );
            }),
            SizedBox(height: 18.r),
          ];
        }),
        DailioOnboardingButton(
          label: 'Join or create another',
          outlined: true,
          onPressed: () => context.go(AppRoutes.joinOrCreate),
        ),
      ],
    );
  }
}
