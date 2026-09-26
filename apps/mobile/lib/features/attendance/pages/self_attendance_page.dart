import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/branch_time.dart';
import '../controllers/attendance_repository.dart';
import '../models/attendance_models.dart';
import '../attendance_error.dart';
import 'attendance_detail_page.dart';

class SelfAttendancePage extends StatefulWidget {
  const SelfAttendancePage({super.key});

  @override
  State<SelfAttendancePage> createState() => _SelfAttendancePageState();
}

class _SelfAttendancePageState extends State<SelfAttendancePage>
    with SingleTickerProviderStateMixin {
  late final AttendanceRepository _repository;
  late final TabController _tabs;
  String? _branchId;
  String? _branchName;
  String _branchTimezone = 'Asia/Kolkata';
  AttendanceSessionModel? _activeSession;
  List<AttendanceSessionModel> _history = [];
  Map<String, dynamic> _policy = const {};
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Timer? _timer;
  DateTime _clock = DateTime.now();
  String? _punchIdempotencyKey;
  String? _punchStatus;
  String _historyPeriod = 'this_month';
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
    final preferences = context.read<PreferencesStorage>();
    _branchId = preferences.activeBranchId;
    _branchName = preferences.activeBranchName;
    _branchTimezone = preferences.activeBranchTimezone ?? _branchTimezone;
    _tabs = TabController(length: 2, vsync: this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _clock = _repository.serverNow);
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final branchId = _branchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'Select an active branch before using attendance.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        _repository.getAttendancePolicy(branchId),
        _repository.getActiveSession(branchId),
        _repository.getSessions(
          branchId,
          _historyPeriod,
          dateFrom: _customFrom == null ? null : _dateOnly(_customFrom!),
          dateTo: _customTo == null ? null : _dateOnly(_customTo!),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _policy = result[0] as Map<String, dynamic>;
        _branchTimezone =
            _policy['branch_timezone']?.toString() ?? _branchTimezone;
        _activeSession = result[1] as AttendanceSessionModel?;
        _history = result[2] as List<AttendanceSessionModel>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = attendanceErrorMessage(error);
        });
      }
    }
  }

  Future<Map<String, double>?> _collectLocation(
      {required bool required}) async {
    if (!required) return {};
    if (!await Geolocator.isLocationServiceEnabled()) {
      _show('Location services are disabled.');
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _show('Location permission is required for this attendance action.');
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
    };
  }

  Future<Map<String, dynamic>?> _collectSelfie({required bool required}) async {
    if (!required) return {};
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) {
      _show('A selfie is required to continue.');
      return null;
    }
    try {
      return await _repository.uploadAttendanceSelfie(_branchId!, file);
    } catch (error) {
      _show('Selfie upload failed: ${attendanceErrorMessage(error)}');
      return null;
    }
  }

  Future<void> _clockIn() async {
    if (_actionLoading || _branchId == null) return;
    setState(() {
      _actionLoading = true;
      _punchStatus = 'submitting';
    });
    try {
      final location = await _collectLocation(
          required: _policy['location_on_clock_in'] == true ||
              _policy['geofence_enabled'] == true);
      if (location == null) {
        if (mounted) setState(() => _punchStatus = 'cancelled');
        return;
      }
      final selfie =
          await _collectSelfie(required: _policy['selfie_on_clock_in'] == true);
      if (selfie == null) {
        if (mounted) setState(() => _punchStatus = 'cancelled');
        return;
      }
      await _repository.clockIn(_branchId!,
          idempotencyKey: _punchIdempotencyKey ??= _newPunchKey(),
          policyVersion: (_policy['version'] as num?)?.toInt(),
          latitude: location['latitude'],
          longitude: location['longitude'],
          accuracy: location['accuracy'],
          selfieStorageKey: selfie['storage_key']?.toString(),
          selfieUploadToken: selfie['upload_token']?.toString(),
          selfieContentType: selfie['content_type']?.toString(),
          selfieSizeBytes: (selfie['size_bytes'] as num?)?.toInt());
      await _load();
      _punchIdempotencyKey = null;
      if (mounted) setState(() => _punchStatus = 'confirmed');
      _show('Clock-in submitted and confirmed.');
    } catch (error) {
      if (mounted) setState(() => _punchStatus = 'error');
      _show(attendanceErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _clockOut() async {
    final session = _activeSession;
    if (_actionLoading || session == null || _branchId == null) return;
    setState(() {
      _actionLoading = true;
      _punchStatus = 'submitting';
    });
    try {
      final location = await _collectLocation(
          required: _policy['location_on_clock_out'] == true ||
              _policy['geofence_enabled'] == true);
      if (location == null) {
        if (mounted) setState(() => _punchStatus = 'cancelled');
        return;
      }
      final selfie = await _collectSelfie(
          required: _policy['selfie_on_clock_out'] == true);
      if (selfie == null) {
        if (mounted) setState(() => _punchStatus = 'cancelled');
        return;
      }
      await _repository.clockOut(_branchId!, session.id,
          idempotencyKey: _punchIdempotencyKey ??= _newPunchKey(),
          policyVersion: session.policyVersion,
          latitude: location['latitude'],
          longitude: location['longitude'],
          accuracy: location['accuracy'],
          selfieStorageKey: selfie['storage_key']?.toString(),
          selfieUploadToken: selfie['upload_token']?.toString(),
          selfieContentType: selfie['content_type']?.toString(),
          selfieSizeBytes: (selfie['size_bytes'] as num?)?.toInt());
      await _load();
      _punchIdempotencyKey = null;
      if (mounted) setState(() => _punchStatus = 'confirmed');
      _show('Clock-out submitted and confirmed.');
    } catch (error) {
      if (mounted) setState(() => _punchStatus = 'error');
      _show(attendanceErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Self attendance', style: TextStyle(fontSize: 18)),
          if (_branchName != null)
            Text(_branchName!, style: const TextStyle(fontSize: 12)),
        ]),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Today'), Tab(text: 'Attendance record')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : TabBarView(
                  controller: _tabs,
                  children: [_todayView(), _historyView()],
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );

  Widget _todayView() {
    final open = _activeSession != null;
    final attendanceEnabled = _policy['punch_required'] != false;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _clockCard(),
          const SizedBox(height: 12),
          _policyCard(),
          const SizedBox(height: 12),
          _sessionCard(_activeSession, open: open),
          if (_punchStatus != null) ...[
            const SizedBox(height: 12),
            _punchStatusCard(),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _actionLoading || (!open && !attendanceEnabled)
                ? null
                : (open ? _clockOut : _clockIn),
            icon: _actionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(open ? Icons.logout : Icons.login),
            label: Text(open
                ? 'Clock out'
                : attendanceEnabled
                    ? 'Clock in'
                    : 'Attendance not required'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                _actionLoading ? null : () => context.push(AppRoutes.qrScanner),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan branch gate QR'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }

  Widget _clockCard() =>
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            DateFormat('EEEE, dd MMM yyyy')
                .format(BranchTime.toBranch(_clock, _branchTimezone)),
            style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Text(
            DateFormat('hh:mm:ss a')
                .format(BranchTime.toBranch(_clock, _branchTimezone)),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
            '${_repository.hasServerTime ? 'Server-synchronized clock' : 'Device clock until server sync'} • server confirms every punch',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ]));

  Widget _policyCard() {
    final requirements = <String>[
      if (_policy['location_on_clock_in'] == true ||
          _policy['location_on_clock_out'] == true ||
          _policy['geofence_enabled'] == true)
        'Location required',
      if (_policy['selfie_on_clock_in'] == true ||
          _policy['selfie_on_clock_out'] == true)
        'Selfie required',
      if (_policy['geofence_enabled'] == true) 'Geofence enabled',
    ];
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Effective attendance policy',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text(requirements.isEmpty
          ? 'No additional evidence required.'
          : requirements.join(' • ')),
      if (_policy['punch_required'] == false) ...[
        const SizedBox(height: 8),
        const Text(
          'Attendance punching is disabled for this policy.',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
        ),
      ],
      const SizedBox(height: 6),
      Text('Late grace: ${_policy['late_grace_minutes'] ?? 15} minutes',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      if (_policy['shift_snapshot'] is Map) ...[
        const SizedBox(height: 6),
        Text(
            'Shift: ${(_policy['shift_snapshot'] as Map)['name'] ?? 'Scheduled'} (${(_policy['shift_snapshot'] as Map)['start_time'] ?? '--'}–${(_policy['shift_snapshot'] as Map)['end_time'] ?? '--'})',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ],
      const SizedBox(height: 4),
      Text(
          'Policy ${_policy['version'] ?? '-'} • ${_policy['source_scope'] ?? 'BRANCH_DEFAULT'}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ]));
  }

  Widget _sessionCard(AttendanceSessionModel? session, {required bool open}) {
    if (session == null) {
      return _card(const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.event_available, color: Colors.green),
        title: Text('No open attendance session'),
        subtitle: Text('Clock in when you begin your session.'),
      ));
    }
    return InkWell(
      onTap: () => _openDetail(session),
      borderRadius: BorderRadius.circular(16),
      child:
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Current session',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Chip(label: Text(open ? 'OPEN' : session.state)),
        ]),
        const SizedBox(height: 10),
        Text(
            'Clock in: ${_time(session.clockInServerTime, session.branchTimezone)}'),
        Text('Duration: ${session.durationLabel}'),
        if (session.hasLocationEvidence)
          const Text('Location evidence recorded',
              style: TextStyle(fontSize: 12, color: Colors.green)),
        const SizedBox(height: 4),
        const Text('Tap for full details',
            style: TextStyle(fontSize: 12, color: Colors.indigo)),
      ])),
    );
  }

  Widget _punchStatusCard() {
    final status = _punchStatus;
    final submitting = status == 'submitting';
    final confirmed = status == 'confirmed';
    final cancelled = status == 'cancelled';
    final color = submitting
        ? Colors.indigo
        : confirmed
            ? Colors.green
            : cancelled
                ? Colors.orange.shade800
                : Colors.red;
    return _card(Row(children: [
      Icon(
          submitting
              ? Icons.sync
              : confirmed
                  ? Icons.check_circle_outline
                  : cancelled
                      ? Icons.info_outline
                      : Icons.error_outline,
          color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          submitting
              ? 'Attendance submission pending server confirmation.'
              : confirmed
                  ? 'Attendance confirmed by the server.'
                  : cancelled
                      ? 'Attendance was not submitted. Review the requirement and try again.'
                      : 'Attendance submission failed. Your retry key is preserved.',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    ]));
  }

  Widget _historyView() {
    return Column(
      children: [
        _historyFilter(),
        Expanded(child: _historyListView()),
      ],
    );
  }

  Widget _historyListView() {
    if (_history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: Text('No attendance records for this period.')),
            ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final session = _history[index];
          return InkWell(
            onTap: () => _openDetail(session),
            borderRadius: BorderRadius.circular(14),
            child: _card(Row(children: [
              CircleAvatar(
                backgroundColor: session.state == 'OPEN'
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                child: Icon(
                    session.state == 'OPEN' ? Icons.timelapse : Icons.check,
                    color:
                        session.state == 'OPEN' ? Colors.orange : Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        DateFormat('EEE, dd MMM yyyy').format(
                            BranchTime.toBranch(session.clockInServerTime,
                                session.branchTimezone ?? _branchTimezone)),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '${_time(session.clockInServerTime, session.branchTimezone)} → ${session.clockOutServerTime == null ? 'Open' : _time(session.clockOutServerTime!, session.branchTimezone)}',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12)),
                  ])),
              Text(session.durationLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          );
        },
      ),
    );
  }

  Widget _historyFilter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in const [
                ('today', 'Today'),
                ('yesterday', 'Yesterday'),
                ('this_week', 'This week'),
                ('this_month', 'This month'),
                ('this_year', 'This year'),
                ('custom', 'Custom'),
              ]) ...[
                ChoiceChip(
                  label: Text(item.$2),
                  selected: _historyPeriod == item.$1,
                  onSelected: (_) => _selectHistoryPeriod(item.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      );

  Future<void> _selectHistoryPeriod(String period) async {
    if (period == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customFrom != null && _customTo != null
            ? DateTimeRange(start: _customFrom!, end: _customTo!)
            : null,
      );
      if (range == null) return;
      _customFrom = range.start;
      _customTo = range.end;
    }
    if (!mounted) return;
    setState(() => _historyPeriod = period);
    await _load();
  }

  void _openDetail(AttendanceSessionModel session) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AttendanceDetailPage(sessionId: session.id)));
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: child,
      );

  String _time(DateTime value, [String? timezone]) => DateFormat('hh:mm a')
      .format(BranchTime.toBranch(value, timezone ?? _branchTimezone));

  String _newPunchKey() =>
      'mobile-attendance-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
