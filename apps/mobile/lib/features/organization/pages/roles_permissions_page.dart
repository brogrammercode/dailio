import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/storage/preferences_storage.dart';

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
      final rolesData = await _repo.getRoles(_orgId);
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

  Future<void> _createRole() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Custom Role',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Receptionist',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => context.pop(nameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final newRoleData = await _repo.createRole(_orgId, name, []);
        final newRole = RoleModel.fromJson(newRoleData);
        setState(() {
          _roles.add(newRole);
          _selectRole(newRole);
        });
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null) return;
    setState(() => _isSubmitting = true);
    try {
      final updatedData = await _repo.updateRole(
          _selectedRole!.id, _selectedRole!.name, _editedPermissions.toList());
      final updatedRole = RoleModel.fromJson(updatedData);

      setState(() {
        final idx = _roles.indexWhere((r) => r.id == updatedRole.id);
        if (idx != -1) _roles[idx] = updatedRole;
        _selectRole(updatedRole);
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Role permissions saved successfully.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        child: _isLoading
            ? _buildSkeleton()
            : _errorMessage != null
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
                          const SizedBox(height: 24),
                          _buildRolesList(),
                          const SizedBox(height: 24),
                          if (_selectedRole != null) ...[
                            _buildRoleScopeCard(),
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

  Widget _buildRoleScopeCard() {
    final role = _selectedRole!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.shield_search, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('${role.name} Scope',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (role.isProtected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade300)),
                  child: const Row(
                    children: [
                      Icon(Iconsax.lock, size: 10, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('PROTECTED',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(
              role.systemKey == 'OWNER'
                  ? 'Full organizational ownership. Unrestricted access to all modules, billing, and settings. Cannot be deleted.'
                  : 'Customizable role. Enable or disable specific access permissions below to restrict operational scope.',
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey, height: 1.5)),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 150),
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
