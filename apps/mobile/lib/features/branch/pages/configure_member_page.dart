import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../organization/models/role_model.dart';
import '../controllers/members_repository.dart';
import '../models/member_model.dart';
import '../controllers/shift_repository.dart';

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
  List<Map<String, dynamic>> _plans = [];

  String? _selectedBranchId;
  String? _selectedShiftId;
  String? _selectedPlanId;
  String? _selectedSalaryStructureId;

  late final MembersRepository _repo;
  late final OrganizationRepository _orgRepo;
  late final String _branchId;
  late final String _orgId;

  bool _isSubmitting = false;

  // Editable fields
  String? _selectedRoleId;
  bool _isGeofenceExempt = false;
  bool _isSelfieMandatory = true;
  bool _isMultiBranch = false;

  // Original state check
  bool get _isDirty {
    if (_member == null) return false;
    if (_selectedRoleId != _member!.role?.id) return true;
    if (_selectedBranchId != _member!.branchId) return true;
    if (_selectedShiftId != _member!.shiftId) return true;
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
      ]);

      final memberData = futures[0] as Map<String, dynamic>;
      final roleMaps = futures[1] as List<Map<String, dynamic>>;
      final roles = roleMaps.map((e) => RoleModel.fromJson(e)).toList();

      final branches = (futures[2] as List).cast<Map<String, dynamic>>();
      final plans = (futures[3] as List).cast<Map<String, dynamic>>();
      final shifts = (futures[4] as List).cast<Map<String, dynamic>>();

      final m = MemberModel.fromJson(memberData['data'] ?? memberData);

      setState(() {
        _member = m;
        _roles = roles;
        _branches = branches;
        _plans = plans;
        _shifts = shifts;
        _selectedRoleId = m.role?.id;
        _selectedBranchId = m.branchId;
        _selectedShiftId = m.shiftId;
        _selectedPlanId = m.subscriptionId;
        _selectedSalaryStructureId = m.salaryStructureId;
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
        'role_id': _selectedRoleId,
        'branch_id': _selectedBranchId,
        'subscription_id': _selectedPlanId,
        'shift_id': _selectedShiftId,
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
                    child: Text(_member!.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
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
        _buildLabel('Primary Role'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedRoleId,
              items: _roles.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.name))).toList(),
              onChanged: (val) => setState(() => _selectedRoleId = val),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Assigned Branch'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Branch Assigned'),
              value: _selectedBranchId,
              items: [const DropdownMenuItem<String>(value: null, child: Text('No Branch (HQ)')), ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name'])))],
              onChanged: (val) => setState(() => _selectedBranchId = val),
            ),
          ),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Shift Assigned'),
              value: _selectedShiftId,
              items: [const DropdownMenuItem<String>(value: null, child: Text('No Shift Assigned')), ..._shifts.map((s) => DropdownMenuItem<String>(value: s['id'], child: Text(s['name'])))],
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Plan Assigned'),
              value: _selectedPlanId,
              items: [const DropdownMenuItem<String>(value: null, child: Text('No Plan Assigned')), ..._plans.map((p) => DropdownMenuItem<String>(value: p['id'], child: Text(p['name'])))],
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
      badge: 'Audit-Enforced',
      children: [
        _buildToggleRow(
            'Exempt from Geofence',
            'Allow clock-in outside the radius',
            _isGeofenceExempt,
            (v) => setState(() => _isGeofenceExempt = v)),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1)),
        _buildToggleRow(
            'Selfie Clock-in Mandatory',
            'Require facial capture at gate kiosk or mobile',
            _isSelfieMandatory,
            (v) => setState(() => _isSelfieMandatory = v)),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1)),
        _buildToggleRow(
            'Multi-Branch Clock-in',
            'Permit cross-attendance at sister clubs',
            _isMultiBranch,
            (v) => setState(() => _isMultiBranch = v)),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('No Salary Structure'),
              value: _selectedSalaryStructureId,
              items: const [DropdownMenuItem<String>(value: null, child: Text('No Salary Structure'))], // TODO: bind actual salary structures once backend supports it
              onChanged: (val) => setState(() => _selectedSalaryStructureId = val),
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
              if (badge != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildToggleRow(String title, String subtitle, bool value,
      ValueChanged<bool>? onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbImage: null,
            activeThumbColor: Colors.orange.shade600),
      ],
    );
  }
}









