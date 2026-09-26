import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../attendance/attendance_ui.dart';
import '../../attendance/attendance_error.dart';
import '../../attendance/controllers/attendance_repository.dart';
import '../../branch/controllers/members_repository.dart';
import '../controllers/organization_repository.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';

String attendancePolicyErrorMessage(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 403) {
      return 'You do not have permission to view or manage attendance policies in this branch.';
    }
    if (error.response?.statusCode == 409) {
      return 'This policy changed in another session. Refresh the page before trying again.';
    }
  }
  return attendanceErrorMessage(error);
}

class AttendancePolicyPage extends StatefulWidget {
  const AttendancePolicyPage({super.key});

  @override
  State<AttendancePolicyPage> createState() => _AttendancePolicyPageState();
}

class _AttendancePolicyPageState extends State<AttendancePolicyPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  bool _punchRequired = true;
  bool _allowManualEntry = false;
  bool _selfieOnClockIn = false;
  bool _selfieOnClockOut = false;
  bool _locationOnClockIn = false;
  bool _locationOnClockOut = false;
  bool _geofenceEnabled = false;
  bool _shiftEnforcementEnabled = false;
  int _earlyArrivalMinutes = 30;
  int _lateGraceMinutes = 15;
  int _maxOpenSessionHours = 24;
  int _geofenceRadiusMeters = 100;
  int _geofenceAccuracyThreshold = 50;
  int _minSessionMinutes = 0;
  String _scope = 'BRANCH';
  String? _selectedRoleId;
  String? _selectedMemberId;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _policies = [];

  String _friendlyError(Object error) {
    return attendancePolicyErrorMessage(error);
  }

  Future<T?> _tryLoad<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      // Policy data is primary. Role/member selectors are optional and may be
      // unavailable to a narrowly scoped policy manager.
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    if (mounted) setState(() => _loadError = null);
    try {
      final prefs = context.read<PreferencesStorage>();
      final branchId = prefs.activeBranchId;
      if (branchId == null) throw Exception('No active branch selected');

      final repo = context.read<AttendanceRepository>();
      final orgId = prefs.activeOrganizationId;
      final results = await Future.wait<dynamic>([
        repo.getAttendancePolicies(branchId),
        if (orgId != null)
          _tryLoad(context
              .read<OrganizationRepository>()
              .getRoles(orgId, branchId: branchId)),
        _tryLoad(context.read<MembersRepository>().listMembers(branchId)),
      ]);
      final policies = results[0] as List<Map<String, dynamic>>;
      final roles = orgId == null || results[1] is! List
          ? <Map<String, dynamic>>[]
          : (results[1] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      final memberResponse = results[orgId == null ? 1 : 2];
      final members =
          ((memberResponse is Map ? memberResponse['data'] as List? : null) ??
                  const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
      final policy = _policyForScope(policies, 'BRANCH', null, null);

      if (mounted) {
        setState(() {
          _punchRequired = policy['punch_required'] ?? true;
          _allowManualEntry = policy['allow_manual_entry'] ?? false;
          _selfieOnClockIn = policy['selfie_on_clock_in'] ?? false;
          _selfieOnClockOut = policy['selfie_on_clock_out'] ?? false;
          _locationOnClockIn = policy['location_on_clock_in'] ?? false;
          _locationOnClockOut = policy['location_on_clock_out'] ?? false;
          _geofenceEnabled = policy['geofence_enabled'] ?? false;
          _shiftEnforcementEnabled =
              policy['shift_enforcement_enabled'] ?? false;
          _earlyArrivalMinutes = policy['early_arrival_minutes'] ?? 30;
          _lateGraceMinutes = policy['late_grace_minutes'] ?? 15;
          _maxOpenSessionHours = policy['max_open_session_hours'] ?? 24;
          _geofenceRadiusMeters = policy['geofence_radius_meters'] ?? 100;
          _geofenceAccuracyThreshold =
              (policy['geofence_accuracy_threshold'] as num?)?.toInt() ?? 50;
          _minSessionMinutes = policy['min_session_minutes'] ?? 0;
          _roles = roles;
          _members = members;
          _policies = policies;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = _friendlyError(e);
        });
      }
    }
  }

  void _selectPolicyScope(String scope, {String? roleId, String? memberId}) {
    final policy = _policyForScope(_policies, scope, roleId, memberId);
    setState(() {
      _scope = scope;
      _selectedRoleId = scope == 'ROLE' ? roleId : null;
      _selectedMemberId = scope == 'MEMBER' ? memberId : null;
      _punchRequired = policy['punch_required'] ?? true;
      _allowManualEntry = policy['allow_manual_entry'] ?? false;
      _selfieOnClockIn = policy['selfie_on_clock_in'] ?? false;
      _selfieOnClockOut = policy['selfie_on_clock_out'] ?? false;
      _locationOnClockIn = policy['location_on_clock_in'] ?? false;
      _locationOnClockOut = policy['location_on_clock_out'] ?? false;
      _geofenceEnabled = policy['geofence_enabled'] ?? false;
      _shiftEnforcementEnabled = policy['shift_enforcement_enabled'] ?? false;
      _earlyArrivalMinutes = policy['early_arrival_minutes'] ?? 30;
      _lateGraceMinutes = policy['late_grace_minutes'] ?? 15;
      _maxOpenSessionHours = policy['max_open_session_hours'] ?? 24;
      _geofenceRadiusMeters = policy['geofence_radius_meters'] ?? 100;
      _geofenceAccuracyThreshold =
          (policy['geofence_accuracy_threshold'] as num?)?.toInt() ?? 50;
      _minSessionMinutes = policy['min_session_minutes'] ?? 0;
    });
  }

  Map<String, dynamic> _policyForScope(List<Map<String, dynamic>> policies,
      String scope, String? roleId, String? memberId) {
    final now = DateTime.now();
    for (final item in policies) {
      final matchesScope = scope == 'ROLE'
          ? item['role_id']?.toString() == roleId && item['member_id'] == null
          : scope == 'MEMBER'
              ? item['member_id']?.toString() == memberId
              : item['role_id'] == null && item['member_id'] == null;
      if (!matchesScope) continue;
      final starts =
          DateTime.tryParse(item['effective_from']?.toString() ?? '');
      final ends = DateTime.tryParse(item['effective_to']?.toString() ?? '');
      if ((starts == null || !starts.isAfter(now)) &&
          (ends == null || ends.isAfter(now))) {
        return item;
      }
    }
    return <String, dynamic>{};
  }

  Future<void> _savePolicy() async {
    if ((_scope == 'ROLE' && _selectedRoleId == null) ||
        (_scope == 'MEMBER' && _selectedMemberId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Choose the role or member before saving this policy.'),
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save attendance policy?'),
        content: const Text(
            'This creates a new policy version for future punches. Existing attendance sessions keep their original policy snapshot.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save version')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final prefs = context.read<PreferencesStorage>();
      final branchId = prefs.activeBranchId!;
      final repo = context.read<AttendanceRepository>();

      await repo.updateAttendancePolicy(branchId, {
        'role_id': _scope == 'ROLE' ? _selectedRoleId : null,
        'member_id': _scope == 'MEMBER' ? _selectedMemberId : null,
        'punch_required': _punchRequired,
        'allow_manual_entry': _allowManualEntry,
        'selfie_on_clock_in': _selfieOnClockIn,
        'selfie_on_clock_out': _selfieOnClockOut,
        'location_on_clock_in': _locationOnClockIn,
        'location_on_clock_out': _locationOnClockOut,
        'geofence_enabled': _geofenceEnabled,
        'shift_enforcement_enabled': _shiftEnforcementEnabled,
        'early_arrival_minutes': _earlyArrivalMinutes,
        'late_grace_minutes': _lateGraceMinutes,
        'max_open_session_hours': _maxOpenSessionHours,
        'geofence_radius_meters': _geofenceRadiusMeters,
        'geofence_accuracy_threshold': _geofenceAccuracyThreshold,
        'min_session_minutes': _minSessionMinutes,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Attendance Policy updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final conflict = e is DioException && e.response?.statusCode == 409;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
        if (conflict) await _loadPolicy();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSwitchRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.orange,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildNumberField(
      String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          SizedBox(
            width: 80,
            child: TextFormField(
              key: ValueKey(
                  'attendance-policy-number-$_scope-${_selectedRoleId ?? _selectedMemberId ?? 'branch'}-$label'),
              initialValue: value.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (val) {
                final numVal = int.tryParse(val);
                if (numVal != null) onChanged(numVal);
              },
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAffectedPreview() {
    if (_scope == 'ROLE' && _selectedRoleId == null ||
        _scope == 'MEMBER' && _selectedMemberId == null) {
      return const SizedBox.shrink();
    }
    final policy =
        _policyForScope(_policies, _scope, _selectedRoleId, _selectedMemberId);
    final count = (policy['affected_member_count'] as num?)?.toInt();
    if (count == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AttendanceUi.accentTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Iconsax.people, size: 18, color: AttendanceUi.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Currently affects $count active ${count == 1 ? 'member' : 'members'}. Future punches use the next saved version.',
              style: TextStyle(
                color: AttendanceUi.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AttendanceUi.canvas,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dailio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Attendance policy',
                style: TextStyle(fontSize: 11, color: AttendanceUi.muted)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AttendanceUi.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))))
          else ...[
            TextButton(
              onPressed: _savePolicy,
              child: const Text('Save',
                  style: TextStyle(
                      color: AttendanceUi.accent, fontWeight: FontWeight.bold)),
            ),
            DailioOverflowMenu<String>(
              items: const [
                DailioMenuItem(
                  value: 'refresh',
                  icon: Icons.refresh,
                  label: 'Refresh',
                ),
              ],
              onSelected: (value) {
                if (value == 'refresh') _loadPolicy();
              },
            ),
            const SizedBox(width: 8),
          ]
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.warning_2, size: 40),
                        const SizedBox(height: 12),
                        const Text('Attendance policy could not be loaded',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadPolicy,
                          icon: const Icon(Iconsax.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCard(
                      title: 'Policy assignment',
                      icon: Iconsax.user_tag,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _scope,
                          decoration: const InputDecoration(
                              labelText: 'Apply policy to'),
                          items: const [
                            DropdownMenuItem(
                                value: 'BRANCH', child: Text('Branch default')),
                            DropdownMenuItem(
                                value: 'ROLE', child: Text('A role')),
                            DropdownMenuItem(
                                value: 'MEMBER', child: Text('One member')),
                          ],
                          onChanged: (value) =>
                              _selectPolicyScope(value ?? 'BRANCH'),
                        ),
                        if (_scope == 'ROLE' && _roles.isEmpty)
                          const Text(
                              'No roles are available with the current permissions.')
                        else if (_scope == 'ROLE')
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRoleId,
                            decoration:
                                const InputDecoration(labelText: 'Role'),
                            items: _roles
                                .map((role) => DropdownMenuItem<String>(
                                      value: role['id']?.toString(),
                                      child: Text(
                                          role['name']?.toString() ?? 'Role'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                _selectPolicyScope('ROLE', roleId: value),
                          ),
                        if (_scope == 'MEMBER' && _members.isEmpty)
                          const Text(
                              'No members are available with the current permissions.')
                        else if (_scope == 'MEMBER')
                          DropdownButtonFormField<String>(
                            initialValue: _selectedMemberId,
                            decoration:
                                const InputDecoration(labelText: 'Member'),
                            items: _members
                                .map((member) => DropdownMenuItem<String>(
                                      value: member['id']?.toString(),
                                      child: Text((member['user'] is Map
                                                  ? member['user']['name']
                                                  : member['name'])
                                              ?.toString() ??
                                          'Member'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                _selectPolicyScope('MEMBER', memberId: value),
                          ),
                        _buildAffectedPreview(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      title: 'Version history',
                      icon: Iconsax.timer,
                      children: [
                        if (_policies.isEmpty)
                          const Text('No saved policy versions yet.')
                        else
                          ..._policies
                              .where((item) => _isSelectedScope(item))
                              .take(8)
                              .map((item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        'Version ${item['version'] ?? '-'}'),
                                    subtitle: Text(
                                        '${_dateLabel(item['effective_from'])} → ${item['effective_to'] == null ? 'Current' : _dateLabel(item['effective_to'])}'),
                                    trailing: item['effective_to'] == null
                                        ? const Chip(label: Text('Active'))
                                        : null,
                                  )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      title: 'Clock In/Out Requirements',
                      icon: Iconsax.clock,
                      children: [
                        _buildSwitchRow(
                            'Manual Punch Required',
                            'Require users to click a button to punch in/out',
                            _punchRequired,
                            (val) => setState(() => _punchRequired = val)),
                        _buildSwitchRow(
                            'Allow manager manual records',
                            'Permit authorized staff to add a record when a member could not punch',
                            _allowManualEntry,
                            (val) => setState(() => _allowManualEntry = val)),
                        _buildSwitchRow(
                            'Selfie on Clock-In',
                            'Require a selfie verification to clock in',
                            _selfieOnClockIn,
                            (val) => setState(() => _selfieOnClockIn = val)),
                        _buildSwitchRow(
                            'Selfie on Clock-Out',
                            'Require a selfie verification to clock out',
                            _selfieOnClockOut,
                            (val) => setState(() => _selfieOnClockOut = val)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      title: 'Location & Geofencing',
                      icon: Iconsax.location,
                      children: [
                        _buildSwitchRow(
                            'Capture Location on Clock-In',
                            'Record GPS coordinates',
                            _locationOnClockIn,
                            (val) => setState(() => _locationOnClockIn = val)),
                        _buildSwitchRow(
                            'Capture Location on Clock-Out',
                            'Record GPS coordinates',
                            _locationOnClockOut,
                            (val) => setState(() => _locationOnClockOut = val)),
                        _buildSwitchRow(
                            'Enforce Geofence',
                            'Only allow clock-ins near the branch location',
                            _geofenceEnabled,
                            (val) => setState(() => _geofenceEnabled = val)),
                        _buildNumberField(
                            'Geofence radius (meters)',
                            _geofenceRadiusMeters,
                            (val) =>
                                setState(() => _geofenceRadiusMeters = val)),
                        _buildNumberField(
                            'Maximum GPS accuracy (meters)',
                            _geofenceAccuracyThreshold,
                            (val) => setState(
                                () => _geofenceAccuracyThreshold = val)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      title: 'Shift Rules & Timings',
                      icon: Iconsax.calendar_tick,
                      children: [
                        _buildSwitchRow(
                            'Enforce Shifts',
                            'Strictly enforce shift start and end times',
                            _shiftEnforcementEnabled,
                            (val) =>
                                setState(() => _shiftEnforcementEnabled = val)),
                        const Divider(height: 24),
                        _buildNumberField(
                            'Early Arrival Allowance (mins)',
                            _earlyArrivalMinutes,
                            (val) =>
                                setState(() => _earlyArrivalMinutes = val)),
                        _buildNumberField(
                            'Late Grace Period (mins)',
                            _lateGraceMinutes,
                            (val) => setState(() => _lateGraceMinutes = val)),
                        _buildNumberField(
                            'Max Open Session (hours)',
                            _maxOpenSessionHours,
                            (val) =>
                                setState(() => _maxOpenSessionHours = val)),
                        _buildNumberField(
                            'Minimum Session (mins)',
                            _minSessionMinutes,
                            (val) => setState(() => _minSessionMinutes = val)),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AttendanceUi.accent),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  bool _isSelectedScope(Map<String, dynamic> item) {
    if (_scope == 'ROLE') {
      return item['role_id']?.toString() == _selectedRoleId &&
          item['member_id'] == null;
    }
    if (_scope == 'MEMBER') {
      return item['member_id']?.toString() == _selectedMemberId;
    }
    return item['role_id'] == null && item['member_id'] == null;
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Unknown date';
    return '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().year}';
  }
}
