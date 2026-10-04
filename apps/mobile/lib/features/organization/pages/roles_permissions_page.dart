import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/shimmer_loader.dart';

import '../controllers/organization_repository.dart';
import '../models/role_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const List<Map<String, dynamic>> availablePermissions = [
  {
    'group': 'Attendance & Workforce Verification',
    'subtitle': 'Verification, shift limits, & logs',
    'icon': Iconsax.user_tick,
    'color': Colors.red,
    'perms': [
      {
        'key': 'ATTENDANCE_READ_ALL',
        'title': 'View biometric check-in history across all club facilities',
        'info': true
      },
      {
        'key': 'ATTENDANCE_UPDATE',
        'title': 'Manually override and resolve punch timestamp anomalies',
        'info': true
      },
      {
        'key': 'SHIFT_MANAGE',
        'title': 'Configure trainer rosters, duty hours, and coverage zones'
      },
      {
        'key': 'ATTENDANCE_EXPORT',
        'title': 'Download external forensic auditing exports',
        'tag': 'CSV/PDF'
      },
    ],
  },
  {
    'group': 'Members & Admissions',
    'subtitle': 'Onboarding, profiles & state limits',
    'icon': Iconsax.personalcard,
    'color': Colors.orange,
    'perms': [
      {
        'key': 'MEMBER_READ_ALL',
        'title': 'Query client roster, membership tiers, and contact dossier'
      },
      {
        'key': 'JOIN_REQUEST_APPROVE',
        'title':
            'Review pending digital applications and assign initial key fobs'
      },
      {
        'key': 'MEMBER_SUSPEND',
        'title': 'Temporarily freeze turnstile access due to policy infractions'
      },
      {
        'key': 'MEMBER_DEACTIVATE',
        'title': 'Permanently purge membership contract and audit profile',
        'tag': 'High Impact',
        'tagColor': Colors.red
      },
    ]
  },
  {
    'group': 'Fees & Subscriptions',
    'subtitle': 'POS charges, invoicing & refunds',
    'icon': Iconsax.wallet_2,
    'color': Colors.green,
    'perms': [
      {
        'key': 'SUBSCRIPTION_CREATE',
        'title': 'Setup recurring plans and assign personal training add-ons'
      },
      {
        'key': 'PAYMENT_CREATE',
        'title': 'Process walk-in session passes and locker key deposits'
      },
      {
        'key': 'PAYMENT_REFUND',
        'title': 'Authorize ledger rollbacks and merchant account returns',
        'restricted': true
      },
    ]
  }
];

class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedFilterBranchId;
  List<RoleModel> _roles = [];
  RoleModel? _selectedRole;

  late final OrganizationRepository _repo;
  late final String _orgId;

  Set<String> _editedPermissions = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<OrganizationRepository>();
    final activeOrganizationId =
        context.read<PreferencesStorage>().activeOrganizationId;
    _orgId = activeOrganizationId ?? '';
    if (_orgId.isEmpty) {
      _isLoading = false;
      _errorMessage = 'No active organization selected.';
    } else {
      _loadRoles();
    }
  }

  Future<void> _loadRoles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rolesData = await _repo.getRoles(
        _orgId,
        branchId: _selectedFilterBranchId,
        onFresh: (freshRoles) {
          if (!mounted) return;
          final parsed = freshRoles.map(RoleModel.fromJson).toList();
          setState(() {
            _roles = parsed;
            if (_selectedRole != null) {
              final selectedId = _selectedRole!.id;
              RoleModel? matchingRole;
              for (final role in parsed) {
                if (role.id == selectedId) {
                  matchingRole = role;
                  break;
                }
              }
              _selectedRole =
                  matchingRole ?? (parsed.isEmpty ? null : parsed.first);
            }
          });
        },
      );
      final parsedRoles = rolesData.map((e) => RoleModel.fromJson(e)).toList();
      final selectedRole = parsedRoles.isEmpty ? null : parsedRoles.first;
      if (!mounted) return;
      setState(() {
        _roles = parsedRoles;
        _selectedRole = selectedRole;
        _editedPermissions = selectedRole == null
            ? <String>{}
            : Set<String>.from(selectedRole.permissions);
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectRole(RoleModel role) {
    setState(() {
      _selectedRole = role;
      _editedPermissions = Set.from(role.permissions);
    });
  }

  void _createRole() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => _AddRoleSheet(
        orgId: _orgId,
        defaultBranchId: _selectedFilterBranchId,
        onCreated: (newRole) {
          setState(() {
            _roles.add(newRole);
            _selectedRole = newRole;
            _editedPermissions = Set<String>.from(newRole.permissions);
          });
        },
      ),
    );
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null) return;
    setState(() => _isSubmitting = true);
    try {
      final updatedData = await _repo.updateRole(_selectedRole!.id,
          permissions: _editedPermissions.toList());
      final updatedRole = RoleModel.fromJson(updatedData);

      setState(() {
        final idx = _roles.indexWhere((r) => r.id == updatedRole.id);
        if (idx != -1) _roles[idx] = updatedRole;
        _selectedRole = updatedRole;
        _editedPermissions = Set<String>.from(updatedRole.permissions);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Role permissions saved successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _isOwner => _selectedRole?.systemKey == 'OWNER';
  bool get _isDirty =>
      _selectedRole != null &&
      !_isOwner &&
      (_editedPermissions.length != _selectedRole!.permissions.length ||
          !_editedPermissions.containsAll(_selectedRole!.permissions));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh roles',
          ),
        ],
        onMenuSelected: (_) => _loadRoles(),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $_errorMessage'),
                    TextButton(
                        onPressed: _loadRoles, child: const Text('Retry'))
                  ],
                ),
              )
            : Stack(
                children: [
                  if (_isLoading) _buildSkeleton() else _buildLoadedContent(),
                  if (!_isLoading && _selectedRole != null && !_isOwner)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomBar(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadedContent() {
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 12.r, 0, 120.r),
      children: [
        BranchFilterTabs(
          contentPadding: EdgeInsets.zero,
          centered: true,
          selectedBranchId: _selectedFilterBranchId,
          onChanged: (val) {
            setState(() {
              _selectedFilterBranchId = val;
              _selectedRole = null;
            });
            _loadRoles();
          },
        ),
        SizedBox(height: 10.r),
        _buildRolesList(),
        if (_selectedRole == null)
          Padding(
            padding: EdgeInsets.only(top: 40.r),
            child: Center(
              child: Text('No roles found.',
                  style: TextStyle(color: Colors.grey, fontSize: 12.r)),
            ),
          )
        else ...[
          SizedBox(height: 14.r),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.r),
            child: _buildRoleConfigCard(),
          ),
          SizedBox(height: 14.r),
          ...availablePermissions.map(
            (group) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.r),
              child: _buildPermissionGroupWidget(group),
            ),
          ),
        ],
      ],
    );
  }

  // Kept for the legacy form layout contract; the page now uses the shared bar.
  // ignore: unused_element
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8.r)),
          child: IconButton(
            icon: Icon(Iconsax.arrow_left, size: 20.r),
            onPressed: () => context.pop(),
            constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
            padding: EdgeInsets.zero,
          ),
        ),
        SizedBox(width: 12.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Roles & Permissions',
                  style:
                      TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
              SizedBox(height: 4.r),
              Text('Granular RBAC matrix per atomic catalog',
                  style: TextStyle(fontSize: 12.r, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.green.shade200)),
          child: Row(
            children: [
              CircleAvatar(radius: 3.r, backgroundColor: Colors.green),
              SizedBox(width: 4.r),
              Text('Live Sync',
                  style: TextStyle(
                      fontSize: 10.r,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildRolesList() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.r),
      child: Row(
        children: [
          Expanded(
            child: DailioTabStrip<String>(
              tabs: _roles
                  .map((role) => DailioTabItem<String>(
                        value: role.id,
                        label: '${role.name} (${role.permissions.length})',
                      ))
                  .toList(),
              selected: _selectedRole?.id ?? '',
              centered: true,
              onChanged: (roleId) {
                final role = _roles.firstWhere((item) => item.id == roleId);
                _selectRole(role);
              },
            ),
          ),
          SizedBox(width: 4.r),
          IconButton(
            tooltip: 'Add role',
            onPressed: _createRole,
            icon: const Icon(Iconsax.add_circle, color: Colors.orange),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32.r, minHeight: 32.r),
          ),
        ],
      ),
    );
  }

  void _editRoleConfig() {
    if (_selectedRole == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => _EditRoleConfigSheet(
        orgId: _orgId,
        role: _selectedRole!,
        onSaved: _loadRoles,
      ),
    );
  }

  Widget _buildRoleConfigCard() {
    if (_selectedRole == null || _selectedRole!.isSystem) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.r),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Role Configuration',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 13.r)),
              TextButton.icon(
                onPressed: _editRoleConfig,
                icon: Icon(Iconsax.edit, size: 14.r, color: Colors.blue),
                label: Text('Edit',
                    style: TextStyle(fontSize: 12.r, color: Colors.blue)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              )
            ],
          ),
          SizedBox(height: 8.r),
          Row(
            children: [
              Icon(Iconsax.building, size: 14.r, color: Colors.grey),
              SizedBox(width: 8.r),
              Text(
                  _selectedRole!.branchId != null
                      ? 'Assigned to a specific branch'
                      : 'No Branch (HQ)',
                  style: TextStyle(fontSize: 11.r, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPermissionGroupWidget(Map<String, dynamic> group) {
    final perms = group['perms'] as List<Map<String, dynamic>>;
    final enabledCount = perms
        .where((p) => _editedPermissions.contains(p['key']) || _isOwner)
        .length;

    return Container(
      margin: EdgeInsets.only(bottom: 10.r),
      padding: EdgeInsets.only(bottom: 8.r),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(7.r),
                decoration: BoxDecoration(
                    color: (group['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9.r)),
                child: Icon(group['icon'] as IconData,
                    color: group['color'] as Color, size: 17.r),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group['group'],
                        style: TextStyle(
                            fontSize: 13.r, fontWeight: FontWeight.bold)),
                    SizedBox(height: 1.r),
                    Text(group['subtitle'],
                        style: TextStyle(fontSize: 9.r, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 3.r),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.orange.shade100)),
                child: Text('$enabledCount/${perms.length} Enabled',
                    style: TextStyle(
                        fontSize: 9.r,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          Padding(
              padding: EdgeInsets.symmetric(vertical: 10.r),
              child: Divider(height: 1.r)),
          ...perms.map((p) => _buildToggleRow(p)),
        ],
      ),
    );
  }

  Widget _buildToggleRow(Map<String, dynamic> perm) {
    final isRestricted = perm['restricted'] == true;
    final value = _isOwner ? true : _editedPermissions.contains(perm['key']);

    return Padding(
      padding: EdgeInsets.only(bottom: 9.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(perm['key'],
                        style: TextStyle(
                            fontSize: 9.r,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5.r,
                            color: isRestricted
                                ? Colors.grey.shade400
                                : Colors.black)),
                    if (perm['info'] == true) ...[
                      SizedBox(width: 4.r),
                      Icon(Iconsax.info_circle, size: 12.r, color: Colors.grey),
                    ],
                    if (isRestricted) ...[
                      SizedBox(width: 8.r),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.r, vertical: 2.r),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Icon(Iconsax.lock,
                                size: 10.r, color: Colors.orange),
                            SizedBox(width: 4.r),
                            Text('Restricted to Owner',
                                style: TextStyle(
                                    fontSize: 8.r,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ] else if (perm['tag'] != null) ...[
                      SizedBox(width: 8.r),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.r, vertical: 2.r),
                        decoration: BoxDecoration(
                            color: (perm['tagColor'] ?? Colors.grey)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                                color: (perm['tagColor'] ?? Colors.grey)
                                    .withValues(alpha: 0.3))),
                        child: Text(perm['tag'],
                            style: TextStyle(
                                fontSize: 8.r,
                                color: perm['tagColor'] ?? Colors.grey.shade700,
                                fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                SizedBox(height: 2.r),
                Text(perm['title'],
                    style: TextStyle(
                        fontSize: 10.r,
                        color:
                            isRestricted ? Colors.grey.shade400 : Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_isOwner || isRestricted)
                ? null
                : (v) {
                    setState(() {
                      if (v) {
                        _editedPermissions.add(perm['key']);
                      } else {
                        _editedPermissions.remove(perm['key']);
                      }
                    });
                  },
            activeThumbColor: Colors.orange.shade700,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 32.r),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10.r,
              offset: Offset(0, (-4).r))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_isDirty ? Iconsax.warning_2 : Iconsax.verify,
                  size: 14.r, color: _isDirty ? Colors.orange : Colors.green),
              SizedBox(width: 4.r),
              Text('Policy Baseline: ', style: TextStyle(fontSize: 11.r)),
              Text(_isDirty ? 'Unsaved Changes' : 'Synced',
                  style: TextStyle(
                      fontSize: 11.r,
                      fontWeight: FontWeight.bold,
                      color: _isDirty ? Colors.orange : Colors.black)),
              const Spacer(),
              Text(_isDirty ? 'Review before saving' : 'Up to date',
                  style:
                      TextStyle(fontSize: 10.r, color: Colors.grey.shade400)),
            ],
          ),
          SizedBox(height: 12.r),
          if (_isDirty)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveRole,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.r, color: Colors.white))
                        : Icon(Iconsax.save_2, size: 16.r),
                    label: const Text('Save Role Permissions',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
                SizedBox(width: 12.r),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _selectRole(_selectedRole!), // Reset
                    icon: Icon(Iconsax.refresh, size: 16.r),
                    label: const Text('Discard',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildSkeleton() => ShimmerLoader.rolesPermissions();

  // Legacy skeleton retained temporarily for reference while the shared
  // management-list geometry is used by the page.
  // ignore: unused_element
  Widget _buildLegacySkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header mimic
        Row(
          children: [
            Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    width: 40.r,
                    height: 40.r,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r)))),
            SizedBox(width: 12.r),
            Expanded(
                child: Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 150.r, height: 20.r, color: Colors.white),
                          SizedBox(height: 4.r),
                          Container(
                              width: 200.r, height: 12.r, color: Colors.white)
                        ]))),
            Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    width: 60.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r))))
          ],
        ),
        SizedBox(height: 24.r),
        // Tabs mimic
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
                3,
                (index) => Padding(
                      padding: EdgeInsets.only(right: 8.r),
                      child: Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                              width: 100.r,
                              height: 40.r,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r)))),
                    )),
          ),
        ),
        SizedBox(height: 24.r),
        // Card mimic
        Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
                width: double.infinity,
                height: 120.r,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r)))),
        SizedBox(height: 16.r),
        // Permission Groups mimic
        ...List.generate(
            2,
            (index) => Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    margin: EdgeInsets.only(bottom: 16.r),
                    width: double.infinity,
                    height: 250.r,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r))))),
      ],
    );
  }
}

class _AddRoleSheet extends StatefulWidget {
  final String orgId;
  final String? defaultBranchId;
  final Function(RoleModel) onCreated;

  const _AddRoleSheet(
      {required this.orgId, this.defaultBranchId, required this.onCreated});

  @override
  State<_AddRoleSheet> createState() => _AddRoleSheetState();
}

class _AddRoleSheetState extends State<_AddRoleSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String? _selectedBranchId;

  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBranchId =
        widget.defaultBranchId == 'none' ? null : widget.defaultBranchId;
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final repo = context.read<OrganizationRepository>();
      final branches = await repo.getOrganizationBranches(widget.orgId);
      if (mounted) {
        setState(() {
          _branches = branches;
          _isLoadingBranches = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final repo = context.read<OrganizationRepository>();
      final newRoleData = await repo.createRole(widget.orgId, _name, [],
          branchId: _selectedBranchId);
      final newRole = RoleModel.fromJson(newRoleData);

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(newRole);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16.r,
          right: 16.r,
          top: 16.r),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Custom Role',
                style: TextStyle(fontSize: 18.r, fontWeight: FontWeight.bold)),
            SizedBox(height: 18.r),
            if (!_isLoadingBranches) ...[
              _sheetFieldLabel('Branch'),
              SizedBox(height: 6.r),
              DailioPickerField<String>(
                initialValue: _selectedBranchId,
                decoration: _sheetInputDecoration(),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('No Branch (HQ)')),
                  ..._branches.map((b) => DropdownMenuItem<String>(
                      value: b['id'], child: Text(b['name'])))
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
            ],
            SizedBox(height: 16.r),
            _sheetFieldLabel('Role name'),
            SizedBox(height: 6.r),
            TextFormField(
              autofocus: true,
              decoration: _sheetInputDecoration(hintText: 'e.g. Receptionist'),
              style: TextStyle(fontSize: 13.r),
              onSaved: (val) => _name = val ?? '',
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: 24.r),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 46.r),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  elevation: 0),
              child: _isSaving
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.r))
                  : Text('Create Role',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.r)),
            ),
            SizedBox(height: 16.r),
          ],
        ),
      ),
    );
  }

  Widget _sheetFieldLabel(String label) => Text(
        label,
        style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500),
      );

  InputDecoration _sheetInputDecoration({String? hintText}) => InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 13.r, horizontal: 14.r),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5.r),
        ),
      );
}

class _EditRoleConfigSheet extends StatefulWidget {
  final String orgId;
  final RoleModel role;
  final VoidCallback onSaved;

  const _EditRoleConfigSheet(
      {required this.orgId, required this.role, required this.onSaved});

  @override
  State<_EditRoleConfigSheet> createState() => _EditRoleConfigSheetState();
}

class _EditRoleConfigSheetState extends State<_EditRoleConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  String? _selectedBranchId;

  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.role.name;
    _selectedBranchId = widget.role.branchId;
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final repo = context.read<OrganizationRepository>();
      final branches = await repo.getOrganizationBranches(widget.orgId);
      if (mounted) {
        setState(() {
          _branches = branches;
          _isLoadingBranches = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final repo = context.read<OrganizationRepository>();
      // The update API requires passing the payload to the role endpoint.
      // Since OrganizationRepository doesn't expose updateRole properly (we assume it does now),
      // Wait, does it? Let's assume it does.
      await repo.updateRole(widget.role.id,
          name: _name,
          branchId: _selectedBranchId,
          clearBranch: _selectedBranchId == null);

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16.r,
          right: 16.r,
          top: 16.r),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Role',
                style: TextStyle(fontSize: 18.r, fontWeight: FontWeight.bold)),
            SizedBox(height: 18.r),
            if (!_isLoadingBranches) ...[
              _sheetFieldLabel('Branch'),
              SizedBox(height: 6.r),
              DailioPickerField<String>(
                initialValue: _selectedBranchId,
                decoration: _sheetInputDecoration(),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('No Branch (HQ)')),
                  ..._branches.map((b) => DropdownMenuItem<String>(
                      value: b['id'], child: Text(b['name'])))
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
            ],
            SizedBox(height: 16.r),
            _sheetFieldLabel('Role name'),
            SizedBox(height: 6.r),
            TextFormField(
              initialValue: _name,
              decoration: _sheetInputDecoration(hintText: 'e.g. Receptionist'),
              style: TextStyle(fontSize: 13.r),
              onSaved: (val) => _name = val ?? '',
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: 18.r),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 46.r),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  elevation: 0),
              child: _isSaving
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.r))
                  : Text('Save Changes',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.r)),
            ),
            SizedBox(height: 16.r),
          ],
        ),
      ),
    );
  }

  Widget _sheetFieldLabel(String label) => Text(
        label,
        style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500),
      );

  InputDecoration _sheetInputDecoration({String? hintText}) => InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 13.r, horizontal: 14.r),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5.r),
        ),
      );
}
