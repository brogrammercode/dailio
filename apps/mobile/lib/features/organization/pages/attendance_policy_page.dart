import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../attendance/controllers/attendance_repository.dart';

class AttendancePolicyPage extends StatefulWidget {
  const AttendancePolicyPage({super.key});

  @override
  State<AttendancePolicyPage> createState() => _AttendancePolicyPageState();
}

class _AttendancePolicyPageState extends State<AttendancePolicyPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool _punchRequired = true;
  bool _selfieOnClockIn = false;
  bool _selfieOnClockOut = false;
  bool _locationOnClockIn = false;
  bool _locationOnClockOut = false;
  bool _geofenceEnabled = false;
  bool _shiftEnforcementEnabled = false;
  int _earlyArrivalMinutes = 30;
  int _lateGraceMinutes = 15;
  int _maxOpenSessionHours = 24;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final prefs = context.read<PreferencesStorage>();
      final branchId = prefs.activeBranchId;
      if (branchId == null) throw Exception('No active branch selected');

      final repo = context.read<AttendanceRepository>();
      final policy = await repo.getAttendancePolicy(branchId);

      if (mounted) {
        setState(() {
          _punchRequired = policy['punch_required'] ?? true;
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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading policy: $e')),
        );
      }
    }
  }

  Future<void> _savePolicy() async {
    setState(() => _isSaving = true);
    try {
      final prefs = context.read<PreferencesStorage>();
      final branchId = prefs.activeBranchId!;
      final repo = context.read<AttendanceRepository>();

      await repo.updateAttendancePolicy(branchId, {
        'punch_required': _punchRequired,
        'selfie_on_clock_in': _selfieOnClockIn,
        'selfie_on_clock_out': _selfieOnClockOut,
        'location_on_clock_in': _locationOnClockIn,
        'location_on_clock_out': _locationOnClockOut,
        'geofence_enabled': _geofenceEnabled,
        'shift_enforcement_enabled': _shiftEnforcementEnabled,
        'early_arrival_minutes': _earlyArrivalMinutes,
        'late_grace_minutes': _lateGraceMinutes,
        'max_open_session_hours': _maxOpenSessionHours,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Attendance Policy updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving policy: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Attendance Policy',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
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
          else
            TextButton(
              onPressed: _savePolicy,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                        (val) => setState(() => _earlyArrivalMinutes = val)),
                    _buildNumberField(
                        'Late Grace Period (mins)',
                        _lateGraceMinutes,
                        (val) => setState(() => _lateGraceMinutes = val)),
                    _buildNumberField(
                        'Max Open Session (hours)',
                        _maxOpenSessionHours,
                        (val) => setState(() => _maxOpenSessionHours = val)),
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
              Icon(icon, size: 20, color: Colors.orange),
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
}
