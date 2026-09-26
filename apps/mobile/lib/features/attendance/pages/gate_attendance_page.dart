import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/attendance_repository.dart';
import '../attendance_error.dart';
import '../attendance_ui.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import 'attendance_detail_page.dart';

List<String> gateAttendanceRequirementLabels(
  Map<String, dynamic> policy, {
  required bool clockOut,
}) {
  final labels = <String>[];
  final locationRequired = clockOut
      ? policy['location_on_clock_out'] == true
      : policy['location_on_clock_in'] == true;
  final selfieRequired = clockOut
      ? policy['selfie_on_clock_out'] == true
      : policy['selfie_on_clock_in'] == true;

  if (locationRequired || policy['geofence_enabled'] == true) {
    labels.add('Location capture');
  }
  if (selfieRequired) labels.add('Live selfie');
  if (policy['geofence_enabled'] == true) labels.add('Geofence validation');
  if (policy['shift_enforcement_enabled'] == true) {
    labels.add('Shift window');
  }
  return labels;
}

Map<String, dynamic>? gateAttendanceShift(Map<String, dynamic> policy) {
  final shift = policy['shift_snapshot'] ?? policy['shift'];
  return shift is Map ? Map<String, dynamic>.from(shift) : null;
}

class GateAttendancePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> invite;

  const GateAttendancePage(
      {super.key, required this.token, required this.invite});

  @override
  State<GateAttendancePage> createState() => _GateAttendancePageState();
}

class _GateAttendancePageState extends State<GateAttendancePage> {
  late final AttendanceRepository _repository;
  bool _loading = false;
  String? _error;

  bool get _scanFromGallery => widget.invite['scan_from_gallery'] == true;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
  }

  Map<String, dynamic> get _branch =>
      (widget.invite['branch'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _policy =>
      (widget.invite['attendance_policy'] as Map?)?.cast<String, dynamic>() ??
      {};

  String get _action =>
      widget.invite['attendance_action']?.toString() ?? 'CLOCK_IN';

  bool get _requiresSelfie => _action == 'CLOCK_OUT'
      ? _policy['selfie_on_clock_out'] == true
      : _policy['selfie_on_clock_in'] == true;

  bool get _requiresLocation => _action == 'CLOCK_OUT'
      ? _policy['location_on_clock_out'] == true
      : _policy['location_on_clock_in'] == true;

  Future<Map<String, double>?> _location() async {
    final required = _requiresLocation || _policy['geofence_enabled'] == true;
    if (!required) return {};
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required at this gate.');
    }
    final position = await Geolocator.getCurrentPosition();
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
    };
  }

  Future<Map<String, dynamic>?> _selfie(String branchId) async {
    if (!_requiresSelfie) return {};
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) throw Exception('A live selfie is required to continue.');
    return _repository.uploadAttendanceSelfie(branchId, file);
  }

  Future<void> _confirmAndPunch() async {
    if (_scanFromGallery) {
      setState(() => _error =
          'For attendance safety, gate attendance must be scanned live with the camera. Return to the scanner and scan the printed QR directly.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_action == 'CLOCK_OUT'
            ? 'Clock out at gate?'
            : 'Clock in at gate?'),
        content: Text(
          'Dailio will apply your assigned attendance policy, capture required evidence, and submit the server-confirmed attendance action for ${_branch['name'] ?? 'this branch'}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final branchId = _branch['id']?.toString();
    if (branchId == null) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      setState(() => _error =
          'Gate attendance needs an internet connection so Dailio can confirm the branch and next action safely.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await _location();
      final selfie = await _selfie(branchId);
      final session = await _repository.qrPunch(
        widget.token,
        idempotencyKey:
            'qr-attendance-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        policyVersion: (_policy['version'] as num?)?.toInt(),
        clientTime: DateTime.now().toUtc().toIso8601String(),
        timezone: _branch['timezone']?.toString() ?? 'Asia/Kolkata',
        latitude: location?['latitude'],
        longitude: location?['longitude'],
        accuracy: location?['accuracy'],
        selfieStorageKey: selfie?['storage_key']?.toString(),
        selfieUploadToken: selfie?['upload_token']?.toString(),
        selfieContentType: selfie?['content_type']?.toString(),
        selfieSizeBytes: (selfie?['size_bytes'] as num?)?.toInt(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => AttendanceDetailPage(sessionId: session.id)));
    } catch (error) {
      if (mounted) setState(() => _error = attendanceErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clockOut = _action == 'CLOCK_OUT';
    final requirements = gateAttendanceRequirementLabels(
      _policy,
      clockOut: clockOut,
    );
    final shift = gateAttendanceShift(_policy);
    return Scaffold(
      backgroundColor: AttendanceUi.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AttendanceUi.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dailio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Gate attendance',
                style: TextStyle(fontSize: 11, color: AttendanceUi.muted)),
          ],
        ),
        actions: [
          DailioOverflowMenu<String>(
            items: const [
              DailioMenuItem(
                value: 'cancel',
                icon: Icons.close,
                label: 'Cancel',
              ),
            ],
            onSelected: (value) {
              if (value == 'cancel') Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_branch['name']?.toString() ?? 'Branch',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(clockOut ? 'Next action: Clock out' : 'Next action: Clock in',
                style: TextStyle(
                    color: AttendanceUi.accent, fontWeight: FontWeight.w700)),
            if (_scanFromGallery) ...[
              const SizedBox(height: 12),
              _card(
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.camera_alt_outlined,
                    color: AttendanceUi.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This QR was selected from your gallery. Use the live camera scan for gate attendance; saved QR images can only be used for branch discovery.',
                    style: const TextStyle(color: AttendanceUi.accent),
                  ),
                ),
              ])),
            ],
            const SizedBox(height: 18),
            Text('Your effective attendance requirements',
                style: const TextStyle(color: AttendanceUi.muted)),
            const SizedBox(height: 8),
            Text(requirements.isEmpty
                ? 'No additional evidence required.'
                : requirements.join(' • ')),
            const SizedBox(height: 6),
            Text(
                'Policy ${_policy['version'] ?? '-'} • ${_policy['source_scope'] ?? 'BRANCH_DEFAULT'}',
                style:
                    const TextStyle(color: AttendanceUi.muted, fontSize: 12)),
            if (shift != null) ...[
              const SizedBox(height: 4),
              Text(
                'Shift: ${shift['name'] ?? 'Scheduled'} (${shift['start_time'] ?? '--'}–${shift['end_time'] ?? '--'})',
                style: const TextStyle(color: AttendanceUi.muted, fontSize: 12),
              ),
            ],
          ])),
          const SizedBox(height: 16),
          if (_error != null)
            _card(Row(children: [
              const Icon(Icons.error_outline, color: AttendanceUi.text),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!)),
            ])),
          if (_error != null) const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _confirmAndPunch,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(clockOut ? Icons.logout : Icons.login),
            label: Text(_loading
                ? 'Submitting…'
                : (clockOut ? 'Confirm clock out' : 'Confirm clock in')),
            style: AttendanceUi.primaryButton().copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AttendanceUi.divider),
        ),
        child: child,
      );
}
