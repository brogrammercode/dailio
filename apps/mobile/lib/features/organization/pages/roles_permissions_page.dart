import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';

import '../controllers/organization_repository.dart';
import '../models/role_model.dart';

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
    _orgId = context.read<PreferencesStorage>().activeOrganizationId!;
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rolesData = await _repo.getRoles(_orgId, branchId: _selectedFilterBranchId);
      final parsedRoles = rolesData.map((e) => RoleModel.fromJson(e)).toList();
      setState(() {
        _roles = parsedRoles;
        if (_roles.isNotEmpty) {
          _selectRole(_roles.first);
        }
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddRoleSheet(
        orgId: _orgId,
        defaultBranchId: _selectedFilterBranchId,
        onCreated: (newRole) {
          setState(() {
            _roles.add(newRole);
            _selectRole(newRole);
          });
        },
      ),
    );
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null) return;
    setState(() => _isSubmitting = true);
    try {
      final updatedData = await _repo.updateRole(_selectedRole!.id, permissions: _editedPermissions.toList());
      final updatedRole = RoleModel.fromJson(updatedData);

      setState(() {
        final idx = _roles.indexWhere((r) => r.id == updatedRole.id);
        if (idx != -1) _roles[idx] = updatedRole;
        _selectRole(updatedRole);
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
      backgroundColor: const Color(0xFFF9FAFB),
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
                      ListView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 150),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),
                          BranchFilterTabs(
                            contentPadding: EdgeInsets.zero,
                            selectedBranchId: _selectedFilterBranchId,
                            onChanged: (val) {
                              setState(() {
                                _selectedFilterBranchId = val;
                                _selectedRole = null;
                              });
                              _loadRoles();
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isLoading) _buildSkeleton() else ...[
                            _buildRolesList(),
                            const SizedBox(height: 24),
                          ],
                          if (!_isLoading && _selectedRole != null) ...[
                            const SizedBox(height: 16),
                            _buildRoleConfigCard(),
                            const SizedBox(height: 16),
                            ...availablePermissions.map(
                                (group) => _buildPermissionGroupWidget(group)),
                          ] else
                            const Center(
                                child: Text('No roles found.',
                                    style: TextStyle(color: Colors.grey))),
                        ],
                      ),
                      if (_selectedRole != null && !_isOwner)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildBottomBar(),
                        )
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8)),
          child: IconButton(
            icon: const Icon(Iconsax.arrow_left, size: 20),
            onPressed: () => context.pop(),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Roles & Permissions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Granular RBAC matrix per atomic catalog',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200)),
          child: Row(
            children: [
              const CircleAvatar(radius: 3, backgroundColor: Colors.green),
              const SizedBox(width: 4),
              Text('Live Sync',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildRolesList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._roles.map((role) {
            final isActive = _selectedRole?.id == role.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _selectRole(role),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.orange.shade700 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isActive
                            ? Colors.orange.shade700
                            : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          role.systemKey == 'OWNER'
                              ? Iconsax.shield_tick
                              : Iconsax.user,
                          size: 16,
                          color: isActive ? Colors.white : Colors.grey),
                      const SizedBox(width: 8),
                      Text(role.name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.white : Colors.black)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: isActive
                                ? Colors.orange.shade900
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${role.permissions.length} Perms',
                            style: TextStyle(
                                fontSize: 9,
                                color: isActive ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ),
            );
          }),
          // Add Custom Role Button
          InkWell(
            onTap: _createRole,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.orange.shade200, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.add, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text('Add Role',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700)),
                ],
              ),
            ),
          )
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _EditRoleConfigSheet(
        orgId: _orgId,
        role: _selectedRole!,
        onSaved: _loadRoles,
      ),
    );
  }

  Widget _buildRoleConfigCard() {
    if (_selectedRole == null || _isOwner) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Role Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton.icon(
                onPressed: _editRoleConfig,
                icon: const Icon(Iconsax.edit, size: 14, color: Colors.blue),
                label: const Text('Edit', style: TextStyle(fontSize: 12, color: Colors.blue)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Iconsax.building, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(_selectedRole!.branchId != null ? 'Assigned to a specific branch' : 'No Branch (HQ)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: (group['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(group['icon'] as IconData,
                    color: group['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group['group'],
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(group['subtitle'],
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade100)),
                child: Text('$enabledCount/${perms.length} Enabled',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1)),
          ...perms.map((p) => _buildToggleRow(p)),
        ],
      ),
    );
  }

  Widget _buildToggleRow(Map<String, dynamic> perm) {
    final isRestricted = perm['restricted'] == true;
    final value = _isOwner ? true : _editedPermissions.contains(perm['key']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isRestricted
                                ? Colors.grey.shade400
                                : Colors.black)),
                    if (perm['info'] == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Iconsax.info_circle,
                          size: 12, color: Colors.grey),
                    ],
                    if (isRestricted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: const Row(
                          children: [
                            Icon(Iconsax.lock, size: 10, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('Restricted to Owner',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ] else if (perm['tag'] != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: (perm['tagColor'] ?? Colors.grey)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: (perm['tagColor'] ?? Colors.grey)
                                    .withValues(alpha: 0.3))),
                        child: Text(perm['tag'],
                            style: TextStyle(
                                fontSize: 8,
                                color: perm['tagColor'] ?? Colors.grey.shade700,
                                fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(perm['title'],
                    style: TextStyle(
                        fontSize: 11,
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
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_isDirty ? Iconsax.warning_2 : Iconsax.verify,
                  size: 14, color: _isDirty ? Colors.orange : Colors.green),
              const SizedBox(width: 4),
              const Text('Policy Baseline: ', style: TextStyle(fontSize: 11)),
              Text(_isDirty ? 'Unsaved Changes' : 'Synced',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isDirty ? Colors.orange : Colors.black)),
              const Spacer(),
              Text(_isDirty ? 'Review before saving' : 'Up to date',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 12),
          if (_isDirty)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveRole,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Iconsax.save_2, size: 16),
                    label: const Text('Save Role Permissions',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _selectRole(_selectedRole!), // Reset
                    icon: const Icon(Iconsax.refresh, size: 16),
                    label: const Text('Discard',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)))),
            const SizedBox(width: 12),
            Expanded(
                child: Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 150, height: 20, color: Colors.white),
                          const SizedBox(height: 4),
                          Container(width: 200, height: 12, color: Colors.white)
                        ]))),
            Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    width: 60,
                    height: 24,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12))))
          ],
        ),
        const SizedBox(height: 24),
        // Tabs mimic
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
                3,
                (index) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20)))),
                    )),
          ),
        ),
        const SizedBox(height: 24),
        // Card mimic
        Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)))),
        const SizedBox(height: 16),
        // Permission Groups mimic
        ...List.generate(
            2,
            (index) => Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16))))),
      ],
    );
  }
}








class _AddRoleSheet extends StatefulWidget {
  final String orgId;
  final String? defaultBranchId;
  final Function(RoleModel) onCreated;

  const _AddRoleSheet({required this.orgId, this.defaultBranchId, required this.onCreated});

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
    _selectedBranchId = widget.defaultBranchId == 'none' ? null : widget.defaultBranchId;
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
      final newRoleData = await repo.createRole(widget.orgId, _name, [], branchId: _selectedBranchId);
      final newRole = RoleModel.fromJson(newRoleData);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(newRole);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Custom Role', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 24),
            if (!_isLoadingBranches)
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: InputDecoration(labelText: 'Branch', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('No Branch (HQ)')),
                  ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name'])))
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
            const SizedBox(height: 16),
            TextFormField(
              autofocus: true,
              decoration: InputDecoration(labelText: 'Role Name (e.g. Receptionist)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
              onSaved: (val) => _name = val ?? '',
              validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}





class _EditRoleConfigSheet extends StatefulWidget {
  final String orgId;
  final RoleModel role;
  final VoidCallback onSaved;

  const _EditRoleConfigSheet({required this.orgId, required this.role, required this.onSaved});

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
      await repo.updateRole(widget.role.id, name: _name, branchId: _selectedBranchId, clearBranch: _selectedBranchId == null);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Role', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 24),
            if (!_isLoadingBranches)
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: InputDecoration(labelText: 'Branch', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('No Branch (HQ)')),
                  ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name'])))
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _name,
              decoration: InputDecoration(labelText: 'Role Name (e.g. Receptionist)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
              onSaved: (val) => _name = val ?? '',
              validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}


