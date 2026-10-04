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
import '../../fees/pages/assign_subscription_page.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/shimmer_loader.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Returns unique, selectable subscription records for the member selector.
///
/// `Member.subscription_id` stores a subscription ID, not a plan ID. Keeping
/// this normalization at the UI boundary prevents stale or duplicate API
/// records from violating DropdownButton's single-value invariant.
List<Map<String, String>> normalizeSubscriptionOptions(
  List<Map<String, dynamic>> subscriptions, {
  String? currentSubscriptionId,
  String? currentPlanName,
}) {
  final options = <Map<String, String>>[];
  final seen = <String>{};

  for (final subscription in subscriptions) {
    final id = subscription['id']?.toString();
    if (id == null || id.isEmpty || !seen.add(id)) continue;

    final plan = subscription['plan'];
    final snapshot = subscription['plan_snapshot'];
    final planMap = plan is Map ? Map<String, dynamic>.from(plan) : null;
    final snapshotMap =
        snapshot is Map ? Map<String, dynamic>.from(snapshot) : null;
    final planName = (planMap?['name'] ??
            snapshotMap?['name'] ??
            subscription['plan_name'] ??
            currentPlanName ??
            'Subscription')
        .toString();
    final status = subscription['status']?.toString();
    final label = status == null || status.isEmpty
        ? planName
        : '$planName · ${status.toLowerCase()}';
    options.add({'id': id, 'label': label});
  }

  // Keep a stale current value selectable while the server/API response is
  // catching up. It is still the subscription ID, never a plan ID.
  if (currentSubscriptionId != null &&
      currentSubscriptionId.isNotEmpty &&
      seen.add(currentSubscriptionId)) {
    options.add({
      'id': currentSubscriptionId,
      'label': currentPlanName ?? 'Current subscription',
    });
  }

  return options;
}

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
  List<Map<String, dynamic>> _subscriptions = [];
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
        _repo.getMember(
          _branchId,
          widget.memberId,
          onFresh: (freshData) {
            if (!mounted) return;
            final freshJson = freshData['data'] is Map
                ? Map<String, dynamic>.from(freshData['data'] as Map)
                : freshData;
            final freshMember = MemberModel.fromJson(freshJson);
            setState(() {
              _member = freshMember;
              _subscriptions =
                  ((freshJson['subscriptions'] as List?) ?? const [])
                      .whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();
            });
          },
        ),
        _orgRepo.getRoles(
          _orgId,
          onFresh: (freshRoles) {
            if (mounted) {
              setState(() => _roles =
                  freshRoles.map((item) => RoleModel.fromJson(item)).toList());
            }
          },
        ),
        _orgRepo.getOrganizationBranches(
          _orgId,
          onFresh: (freshBranches) {
            if (mounted) setState(() => _branches = freshBranches);
          },
        ),
        context.read<ShiftRepository>().listShifts(
          _orgId,
          onFresh: (freshShifts) {
            if (mounted) setState(() => _shifts = freshShifts);
          },
        ),
        context.read<PayrollRepository>().listSalaryStructures(
          _orgId,
          onFresh: (freshStructures) {
            if (mounted) setState(() => _salaryStructures = freshStructures);
          },
        ),
        _repo.listMembers(
          _branchId,
          limit: 100,
          onFresh: (freshData) {
            if (!mounted) return;
            final freshMembers = ((freshData['data'] as List?) ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) => item['id']?.toString() != widget.memberId)
                .toList();
            setState(() => _branchMembers = freshMembers);
          },
        ),
      ]);

      final memberData = futures[0] as Map<String, dynamic>;
      final roleMaps = futures[1] as List<Map<String, dynamic>>;
      final roles = roleMaps.map((e) => RoleModel.fromJson(e)).toList();

      final branches = (futures[2] as List).cast<Map<String, dynamic>>();
      final shifts = (futures[3] as List).cast<Map<String, dynamic>>();
      final structures = (futures[4] as List).cast<Map<String, dynamic>>();
      final memberResponse = futures[5] as Map<String, dynamic>;
      final branchMembers = ((memberResponse['data'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['id']?.toString() != widget.memberId)
          .toList();

      final memberJson = memberData['data'] is Map
          ? Map<String, dynamic>.from(memberData['data'] as Map)
          : memberData;
      final m = MemberModel.fromJson(memberJson);
      final subscriptions = ((memberJson['subscriptions'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _member = m;
        _roles = roles;
        _branches = branches;
        _shifts = shifts;
        _salaryStructures = structures;
        _subscriptions = subscriptions;
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
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh member',
          ),
        ],
        onMenuSelected: (_) => _loadData(),
      ),
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
                            padding:
                                EdgeInsets.fromLTRB(16.r, 16.r, 16.r, 120.r),
                            children: [
                              _buildProfileInfo(),
                              SizedBox(height: 16.r),
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
                                    EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 32.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10.r,
                                        offset: Offset(0, (-4).r))
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : _saveChanges,
                                  icon: _isSubmitting
                                      ? SizedBox(
                                          width: 16.r,
                                          height: 16.r,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.r))
                                      : Icon(Iconsax.save_2, size: 18.r),
                                  label: const Text('Save Member Configuration',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.r),
                                    minimumSize: const Size(double.infinity, 0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r)),
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
      ),
    );
  }

  Widget _buildSkeleton() => ShimmerLoader.settingsForm(withAvatar: true);

  // Legacy skeleton retained temporarily for reference while the shared
  // settings-form geometry is used by the page.
  // ignore: unused_element
  Widget _buildLegacySkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: EdgeInsets.all(24.r),
        children: [
          Row(
            children: [
              Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r))),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150.r, height: 20.r, color: Colors.white),
                    SizedBox(height: 8.r),
                    Container(width: 100.r, height: 12.r, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.r),
          Container(
              height: 120.r,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r))),
          SizedBox(height: 16.r),
          Container(
              height: 180.r,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r))),
          SizedBox(height: 16.r),
          Container(
              height: 180.r,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r))),
        ],
      ),
    );
  }

  // Kept for the legacy layout contract; the page now uses the shared bar.
  // ignore: unused_element
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
              Text('Configure Member',
                  style:
                      TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
              SizedBox(height: 4.r),
              Text(
                  'Member #${_member!.membershipNumber.isNotEmpty ? _member!.membershipNumber : _member!.id.substring(0, 8)} Ã¢â‚¬Â¢ ${_member!.name}',
                  style: TextStyle(fontSize: 12.r, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: statusColor.withValues(alpha: 0.2))),
          child: Row(
            children: [
              CircleAvatar(radius: 4.r, backgroundColor: statusColor),
              SizedBox(width: 6.r),
              Text(_member!.status,
                  style: TextStyle(
                      fontSize: 10.r,
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
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => showDailioMemberProfileSheet(
                  context,
                  DailioMemberPreview(
                    memberId: _member!.id,
                    name: _member!.name,
                    role: _member!.role?.name ?? 'Member',
                    status: _member!.status,
                    avatarUrl: _member!.avatarUrl,
                    phone: _member!.phone,
                    email: _member!.email,
                    membershipNumber: _member!.membershipNumber,
                    subscriptionLabel: _member!.activeSubscription?.planName,
                  ),
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28.r,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: _member!.avatarUrl != null
                          ? NetworkImage(_member!.avatarUrl!)
                          : null,
                      child: _member!.avatarUrl == null
                          ? Text(_member!.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 20.r,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800))
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2.r),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                            radius: 8.r,
                            backgroundColor: Colors.orange.shade600,
                            child: Icon(Icons.bolt,
                                size: 10.r, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(width: 16.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(_member!.name,
                                style: TextStyle(
                                    fontSize: 16.r,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 8.r),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.r, vertical: 4.r),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4.r)),
                          child: Text('ID | $displayId',
                              style: TextStyle(
                                  fontSize: 10.r,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        )
                      ],
                    ),
                    SizedBox(height: 4.r),
                    Row(children: [
                      Icon(Iconsax.sms, size: 12.r, color: Colors.grey),
                      SizedBox(width: 4.r),
                      Expanded(
                          child: Text(_member!.email ?? 'No email',
                              style:
                                  TextStyle(fontSize: 11.r, color: Colors.grey),
                              overflow: TextOverflow.ellipsis))
                    ]),
                    SizedBox(height: 2.r),
                    Row(children: [
                      Icon(Iconsax.call, size: 12.r, color: Colors.grey),
                      SizedBox(width: 4.r),
                      Expanded(
                          child: Text(_member!.phone ?? 'No phone',
                              style:
                                  TextStyle(fontSize: 11.r, color: Colors.grey),
                              overflow: TextOverflow.ellipsis))
                    ]),
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: 16.r),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.r),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.calendar_1,
                          size: 18.r, color: Colors.orange.shade400),
                      SizedBox(width: 8.r),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JOINED',
                              style: TextStyle(
                                  fontSize: 9.r,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(_member!.joinedAt?.split('T')[0] ?? 'N/A',
                              style: TextStyle(
                                  fontSize: 12.r, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.r),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle),
                        child: Icon(Icons.local_fire_department,
                            size: 14.r, color: Colors.white),
                      ),
                      SizedBox(width: 8.r),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STREAK',
                              style: TextStyle(
                                  fontSize: 9.r,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text('0 Days',
                              style: TextStyle(
                                  fontSize: 12.r,
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
          spacing: 8.r,
          runSpacing: 8.r,
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
        SizedBox(height: 6.r),
        Text(
          'Attendance policy resolution checks a direct member policy first, then the selected roles in this order, then the branch default.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.r),
        ),
        SizedBox(height: 16.r),
        _buildLabel('Assigned Branch'),
        DailioPickerField<String>(
          initialValue: _selectedBranchId,
          decoration: _pickerDecoration('No Branch Assigned'),
          items: [
            const DropdownMenuItem<String>(
                value: null, child: Text('No Branch (HQ)')),
            ..._branches.map((b) => DropdownMenuItem<String>(
                value: b['id'], child: Text(b['name'])))
          ],
          onChanged: (val) => setState(() => _selectedBranchId = val),
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
        DailioPickerField<String>(
          initialValue: _selectedManagerId,
          decoration: _pickerDecoration('No manager assigned'),
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
        SizedBox(height: 6.r),
        Text(
          'Team-scoped attendance access follows this branch reporting tree; it does not come from the member role name.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.r),
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
        DailioPickerField<String>(
          initialValue: _selectedShiftId,
          decoration: _pickerDecoration('No Shift Assigned'),
          items: [
            const DropdownMenuItem<String>(
                value: null, child: Text('No Shift Assigned')),
            ..._shifts.map((s) => DropdownMenuItem<String>(
                value: s['id'], child: Text(s['name'])))
          ],
          onChanged: (val) => setState(() => _selectedShiftId = val),
        ),
      ],
    );
  }

  Widget _buildSubscription() {
    final subscriptionOptions = normalizeSubscriptionOptions(
      _subscriptions,
      currentSubscriptionId: _member?.subscriptionId,
      currentPlanName: _member?.activeSubscription?.planName,
    );
    final subscriptionIds =
        subscriptionOptions.map((option) => option['id']).toSet();
    final selectedSubscriptionId =
        subscriptionIds.contains(_selectedPlanId) ? _selectedPlanId : null;

    return _buildSectionCard(
      title: 'Subscription Plan',
      icon: Iconsax.card,
      children: [
        _buildLabel('Allotted Plan'),
        DailioPickerField<String>(
          initialValue: selectedSubscriptionId,
          decoration: _pickerDecoration('No Plan Assigned'),
          items: [
            const DropdownMenuItem<String>(
                value: null, child: Text('No Plan Assigned')),
            ...subscriptionOptions.map((subscription) =>
                DropdownMenuItem<String>(
                    value: subscription['id'],
                    child: Text(subscription['label'] ?? 'Subscription')))
          ],
          onChanged: (val) => setState(() => _selectedPlanId = val),
        ),
        SizedBox(height: 10.r),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _member == null
                ? null
                : () async {
                    final assigned = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            AssignSubscriptionPage(member: _member!),
                      ),
                    );
                    if (assigned == true && mounted) await _loadData();
                  },
            icon: Icon(Iconsax.add_circle, size: 17.r),
            label: const Text('Assign a new plan'),
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
        Text(
          'Attendance rules are assigned by branch, role, or directly to this member. Use the policy assignment screen to create a real versioned override.',
          style: TextStyle(fontSize: 12.r, color: Colors.grey),
        ),
        SizedBox(height: 12.r),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.attendancePolicy),
          icon: Icon(Iconsax.setting_2, size: 17.r),
          label: const Text('Manage attendance policies'),
        ),
      ],
    );
  }

  Widget _buildAdminControls() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.r),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(Iconsax.setting_2,
                      color: Colors.orange, size: 18.r)),
              SizedBox(width: 12.r),
              Expanded(
                  child: Text('Administrative\nControls',
                      style: TextStyle(
                          fontSize: 12.r, fontWeight: FontWeight.bold))),
              Icon(Iconsax.user_add, size: 14.r, color: Colors.orange),
              SizedBox(width: 4.r),
              Text('Assign Additional\nRole',
                  style: TextStyle(
                      fontSize: 10.r,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16.r),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                Icon(Iconsax.receipt_item, size: 16.r, color: Colors.orange),
                SizedBox(width: 12.r),
                Text('Issue Fine / Fee Adjustment',
                    style:
                        TextStyle(fontSize: 12.r, fontWeight: FontWeight.bold)),
                Spacer(),
                Icon(Iconsax.arrow_right_3, size: 14.r, color: Colors.grey),
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
        DailioPickerField<String>(
          initialValue: _selectedSalaryStructureId,
          decoration: _pickerDecoration('No Salary Structure'),
          items: [
            const DropdownMenuItem<String>(
                value: null, child: Text('No Salary Structure')),
            ..._salaryStructures.map((s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(s['name']),
                )),
          ],
          onChanged: (val) => setState(() => _selectedSalaryStructureId = val),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.red.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.warning_2, size: 14.r, color: Colors.red),
              SizedBox(width: 8.r),
              Text('DANGER ZONE',
                  style: TextStyle(
                      fontSize: 10.r,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800)),
            ],
          ),
          SizedBox(height: 16.r),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _member!.status == 'SUSPENDED' ? null : _suspendMember,
                  icon: Icon(Iconsax.minus_cirlce, size: 14.r),
                  label: Text('Suspend Access',
                      style: TextStyle(fontSize: 11.r, color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.r),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _deactivateMember,
                  icon: Icon(Iconsax.close_circle, size: 14.r),
                  label: Text('Deactivate', style: TextStyle(fontSize: 11.r)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
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

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      String? badge,
      Color? badgeColor,
      Color? badgeTextColor,
      required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.r),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(icon, color: Colors.orange, size: 18.r)),
              SizedBox(width: 12.r),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 12.r, fontWeight: FontWeight.bold))),
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
                  decoration: BoxDecoration(
                      color: badgeColor ?? Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16.r)),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 9.r,
                          color: badgeTextColor ?? Colors.grey.shade600,
                          fontWeight: FontWeight.bold)),
                )
            ],
          ),
          SizedBox(height: 16.r),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.r),
      child: Text(text,
          style: TextStyle(fontSize: 11.r, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _pickerDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.r, color: Color(0xFF777777)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 13.r),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Color(0xFFFF8A00), width: 1.4.r),
        ),
      );
}
