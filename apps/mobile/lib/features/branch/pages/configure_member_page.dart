import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/router/route_names.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../organization/models/role_model.dart';
import '../controllers/members_repository.dart';
import '../models/member_model.dart';
import '../controllers/shift_repository.dart';
import '../controllers/payroll_repository.dart';

class ConfigureMemberPage extends StatefulWidget {
  final String memberId;
  const ConfigureMemberPage({super.key, required this.memberId});

  @override
  State<ConfigureMemberPage> createState() => _ConfigureMemberPageState();
}

class _ConfigureMemberPageState extends State<ConfigureMemberPage> {
  bool _isLoading = true;
  String? _errorMessage;
  MemberModel? _member;
  List<RoleModel> _roles = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _salaryStructures = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _branchMembers = [];

  String? _selectedBranchId;
  String? _selectedShiftId;
  String? _selectedPlanId;
  String? _selectedSalaryStructureId;
  String? _selectedManagerId;

  late final MembersRepository _repo;
  late final OrganizationRepository _orgRepo;
  late final String _branchId;
  late final String _orgId;

  bool _isSubmitting = false;

  // Editable fields
  Set<String> _selectedRoleIds = <String>{};
  // Original state check
  bool get _isDirty {
    if (_member == null) return false;
    if (!setEquals(_selectedRoleIds, _member!.roleIds.toSet())) return true;
    if (_selectedBranchId != _member!.branchId) return true;
    if (_selectedShiftId != _member!.shiftId) return true;
    if (_selectedManagerId != _member!.managerMemberId) return true;
    if (_selectedPlanId != _member!.subscriptionId) return true;
    if (_selectedSalaryStructureId != _member!.salaryStructureId) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _repo = context.read<MembersRepository>();
    _orgRepo = context.read<OrganizationRepository>();
    _branchId = context.read<PreferencesStorage>().activeBranchId!;
    _orgId = context.read<PreferencesStorage>().activeOrganizationId!;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final futures = await Future.wait([
        _repo.getMember(_branchId, widget.memberId),
        _orgRepo.getRoles(_orgId),
        _orgRepo.getOrganizationBranches(_orgId),
        _orgRepo.getOrganizationPlans(_orgId),
        context.read<ShiftRepository>().listShifts(_orgId),
        context.read<PayrollRepository>().listSalaryStructures(_orgId),
        _repo.listMembers(_branchId, limit: 100),
      ]);

      final memberData = futures[0] as Map<String, dynamic>;
      final roleMaps = futures[1] as List<Map<String, dynamic>>;
      final roles = roleMaps.map((e) => RoleModel.fromJson(e)).toList();

      final branches = (futures[2] as List).cast<Map<String, dynamic>>();
      final plans = (futures[3] as List).cast<Map<String, dynamic>>();
      final shifts = (futures[4] as List).cast<Map<String, dynamic>>();
      final structures = (futures[5] as List).cast<Map<String, dynamic>>();
      final memberResponse = futures[6] as Map<String, dynamic>;
      final branchMembers = ((memberResponse['data'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['id']?.toString() != widget.memberId)
          .toList();

      final m = MemberModel.fromJson(memberData['data'] ?? memberData);

      setState(() {
        _member = m;
        _roles = roles;
        _branches = branches;
        _plans = plans;
        _shifts = shifts;
        _salaryStructures = structures;
        _branchMembers = branchMembers;
        _selectedRoleIds = m.roleIds.toSet();
        _selectedBranchId = m.branchId;
        _selectedShiftId = m.shiftId;
        _selectedPlanId = m.subscriptionId;
        _selectedSalaryStructureId = m.salaryStructureId;
        _selectedManagerId = m.managerMemberId;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_member == null || !_isDirty) return;
    setState(() => _isSubmitting = true);

    try {
      await _repo.updateMember(_branchId, widget.memberId, {
        'role_id': _selectedRoleIds.isEmpty ? null : _selectedRoleIds.first,
        'role_ids': _selectedRoleIds.isEmpty ? null : _selectedRoleIds.toList(),
        'branch_id': _selectedBranchId,
        'subscription_id': _selectedPlanId,
        'shift_id': _selectedShiftId,
        'manager_member_id': _selectedManagerId,
        'salary_structure_id': _selectedSalaryStructureId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member configuration saved!')));
      await _loadData(); // reload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving changes: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _suspendMember() async {
    if (_member == null) return;
    setState(() => _isSubmitting = true);
    try {
      await _repo.suspendMember(
          _branchId, widget.memberId, 'Suspended by admin');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member suspended successfully.')));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deactivateMember() async {
    if (_member == null) return;
    setState(() => _isSubmitting = true);
    try {
      await _repo.deactivateMember(
          _branchId, widget.memberId, 'Deactivated by admin');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member deactivated successfully.')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
                            onPressed: _loadData, child: const Text('Retry'))
                      ],
                    ),
                  )
                : _member == null
                    ? const Center(child: Text('Member not found'))
                    : Stack(
                        children: [
                          ListView(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              _buildProfileInfo(),
                              const SizedBox(height: 16),
                              _buildRoleAndFacility(),
                              _buildReportingLine(),
                              _buildAssignedWork(),
                              _buildSubscription(),
                              _buildPolicyOverrides(),
                              _buildAdminControls(),
                              _buildPayroll(),
                              _buildDangerZone(),
                            ],
                          ),

                          // Bottom Bar
                          if (_isDirty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 16, 24, 32),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, -4))
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : _saveChanges,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Icon(Iconsax.save_2, size: 18),
                                  label: const Text('Save Member Configuration',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    minimumSize: const Size(double.infinity, 0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 20, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 12, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
              height: 120,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Container(
              height: 180,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Container(
              height: 180,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final statusColor = _member!.status == 'ACTIVE'
        ? Colors.green
        : (_member!.status == 'SUSPENDED' ? Colors.red : Colors.grey);
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configure Member',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  'Member #${_member!.membershipNumber.isNotEmpty ? _member!.membershipNumber : _member!.id.substring(0, 8)} Ã¢â‚¬Â¢ ${_member!.name}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.2))),
          child: Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: statusColor),
              const SizedBox(width: 6),
              Text(_member!.status,
                  style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildProfileInfo() {
    final displayId = _member!.membershipNumber.isNotEmpty
        ? _member!.membershipNumber
        : _member!.id.substring(0, 8);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage: _member!.avatarUrl != null
                        ? NetworkImage(_member!.avatarUrl!)
                        : null,
                    child: _member!.avatarUrl == null
                        ? Text(_member!.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.orange.shade600,
                          child: const Icon(Icons.bolt,
                              size: 10, color: Colors.white)),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(_member!.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('ID | $displayId',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Iconsax.sms, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(_member!.email ?? 'No email',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis))
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Iconsax.call, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(_member!.phone ?? 'No phone',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis))
                    ]),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.calendar_1,
                          size: 18, color: Colors.orange.shade400),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('JOINED',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(_member!.joinedAt?.split('T')[0] ?? 'N/A',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.local_fire_department,
                            size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STREAK',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text('0 Days',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRoleAndFacility() {
    return _buildSectionCard(
      title: 'Role & Facility Access',
      icon: Iconsax.building_4,
      children: [
        _buildLabel('Assigned roles (first is primary)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _roles
              .map((role) => FilterChip(
                    label: Text(role.name),
                    selected: _selectedRoleIds.contains(role.id),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedRoleIds.add(role.id);
                      } else {
                        _selectedRoleIds.remove(role.id);
                      }
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(
          'Attendance policy resolution checks a direct member policy first, then the selected roles in this order, then the branch default.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildLabel('Assigned Branch'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Branch Assigned'),
              value: _selectedBranchId,
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('No Branch (HQ)')),
                ..._branches.map((b) => DropdownMenuItem<String>(
                    value: b['id'], child: Text(b['name'])))
              ],
              onChanged: (val) => setState(() => _selectedBranchId = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportingLine() {
    return _buildSectionCard(
      title: 'Reporting line',
      icon: Iconsax.hierarchy,
      children: [
        _buildLabel('Direct manager'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No manager assigned'),
              value: _selectedManagerId,
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('No manager assigned')),
                ..._branchMembers.map((member) => DropdownMenuItem<String>(
                      value: member['id']?.toString(),
                      child: Text(
                        (member['user'] is Map
                                    ? member['user']['name']
                                    : member['name'])
                                ?.toString() ??
                            'Member',
                      ),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedManagerId = value),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Team-scoped attendance access follows this branch reporting tree; it does not come from the member role name.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAssignedWork() {
    return _buildSectionCard(
      title: 'Assigned Work Shift',
      icon: Iconsax.clock,
      children: [
        _buildLabel('Primary Shift'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Shift Assigned'),
              value: _selectedShiftId,
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('No Shift Assigned')),
                ..._shifts.map((s) => DropdownMenuItem<String>(
                    value: s['id'], child: Text(s['name'])))
              ],
              onChanged: (val) => setState(() => _selectedShiftId = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscription() {
    return _buildSectionCard(
      title: 'Subscription Plan',
      icon: Iconsax.card,
      children: [
        _buildLabel('Allotted Plan'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Plan Assigned'),
              value: _selectedPlanId,
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('No Plan Assigned')),
                ..._plans.map((p) => DropdownMenuItem<String>(
                    value: p['id'], child: Text(p['name'])))
              ],
              onChanged: (val) => setState(() => _selectedPlanId = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyOverrides() {
    return _buildSectionCard(
      title: 'Policy Overrides',
      icon: Iconsax.shield_tick,
      badge: 'Managed in Attendance Policy',
      children: [
        const Text(
          'Attendance rules are assigned by branch, role, or directly to this member. Use the policy assignment screen to create a real versioned override.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.attendancePolicy),
          icon: const Icon(Iconsax.setting_2, size: 17),
          label: const Text('Manage attendance policies'),
        ),
      ],
    );
  }

  Widget _buildAdminControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Iconsax.setting_2,
                      color: Colors.orange, size: 18)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Administrative\nControls',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
              const Icon(Iconsax.user_add, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              const Text('Assign Additional\nRole',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
            child: const Row(
              children: [
                Icon(Iconsax.receipt_item, size: 16, color: Colors.orange),
                SizedBox(width: 12),
                Text('Issue Fine / Fee Adjustment',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Spacer(),
                Icon(Iconsax.arrow_right_3, size: 14, color: Colors.grey),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPayroll() {
    return _buildSectionCard(
      title: 'Payroll & Salary',
      icon: Iconsax.money_3,
      children: [
        _buildLabel('Salary Structure'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Salary Structure'),
              value: _selectedSalaryStructureId,
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('No Salary Structure')),
                ..._salaryStructures.map((s) => DropdownMenuItem<String>(
                      value: s['id'],
                      child: Text(s['name']),
                    )),
              ],
              onChanged: (val) =>
                  setState(() => _selectedSalaryStructureId = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.red.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.warning_2, size: 14, color: Colors.red),
              const SizedBox(width: 8),
              Text('DANGER ZONE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _member!.status == 'SUSPENDED' ? null : _suspendMember,
                  icon: const Icon(Iconsax.minus_cirlce, size: 14),
                  label: const Text('Suspend Access',
                      style: TextStyle(fontSize: 11, color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _deactivateMember,
                  icon: const Icon(Iconsax.close_circle, size: 14),
                  label:
                      const Text('Deactivate', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
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

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      String? badge,
      Color? badgeColor,
      Color? badgeTextColor,
      required List<Widget> children}) {
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
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: Colors.orange, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: badgeColor ?? Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 9,
                          color: badgeTextColor ?? Colors.grey.shade600,
                          fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
