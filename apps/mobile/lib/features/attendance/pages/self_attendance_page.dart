import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/branch_time.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/attendance_repository.dart';
import '../models/attendance_models.dart';
import '../attendance_error.dart';
import '../attendance_ui.dart';
import 'attendance_detail_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
    final preferences = context.read<PreferencesStorage>();
    _branchId = preferences.activeBranchId;
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
        _repository.getAttendancePolicy(
          branchId,
          onFresh: (freshPolicy) {
            if (mounted) {
              setState(() {
                _policy = freshPolicy;
              });
            }
          },
        ),
        _repository.getActiveSession(
          branchId,
          onFresh: (freshSession) {
            if (mounted) {
              setState(() {
                _activeSession = freshSession;
              });
            }
          },
        ),
        _repository.getSessions(
          branchId,
          _historyPeriod,
          onFresh: (freshSessions) {
            if (mounted) setState(() => _history = freshSessions);
          },
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
    if (_requiresQrForCurrentAction) {
      context.push(AppRoutes.qrScanner);
      return;
    }
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
    if (_requiresQrForCurrentAction) {
      context.push(AppRoutes.qrScanner);
      return;
    }
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
      backgroundColor: AttendanceUi.canvas,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Icons.refresh,
            label: 'Refresh',
          ),
        ],
        onMenuSelected: (value) {
          if (value == 'refresh') _load();
        },
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(44.r),
          child: AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) => DailioTabStrip<String>(
              tabs: const [
                DailioTabItem(value: 'today', label: 'Today'),
                DailioTabItem(value: 'history', label: 'Attendance record'),
              ],
              selected: _tabs.index == 0 ? 'today' : 'history',
              onChanged: (value) => _tabs.animateTo(value == 'today' ? 0 : 1),
            ),
          ),
        ),
      ),
      body: _loading
          ? ShimmerLoader.selfAttendance()
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
          padding: EdgeInsets.all(24.r),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 42.r, color: AttendanceUi.muted),
            SizedBox(height: 12.r),
            Text(_error!, textAlign: TextAlign.center),
            SizedBox(height: 12.r),
            OutlinedButton(
              onPressed: _load,
              style: AttendanceUi.outlinedButton(),
              child: const Text('Try again'),
            ),
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
        padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 24.r),
        children: [
          SizedBox(height: 32.r),
          _actionCard(open: open, attendanceEnabled: attendanceEnabled),
          if (_punchStatus != null) ...[
            SizedBox(height: 12.r),
            _punchStatusCard(),
          ],
          SizedBox(height: 52.r),
          _policyParameters(),
          if (open) ...[
            SizedBox(height: 12.r),
            _ongoingTimeline(_activeSession!),
          ],
        ],
      ),
    );
  }

  Widget _actionCard({
    required bool open,
    required bool attendanceEnabled,
  }) {
    final now = BranchTime.toBranch(_clock, _branchTimezone);
    final record = _todayRecord(now);
    final canPunch = open || attendanceEnabled;
    final showQr = canPunch && _requiresQrForCurrentAction;
    final actionLabel = showQr
        ? 'Scan QR code'
        : open
            ? 'Clock out'
            : attendanceEnabled
                ? 'Clock in'
                : 'Attendance off';
    final actionIcon = showQr
        ? Icons.qr_code_scanner
        : open
            ? Icons.logout
            : Icons.login;

    return Column(
      children: [
        Text(
          DateFormat('hh:mm a').format(now),
          style: TextStyle(
            color: AttendanceUi.text,
            fontSize: 34.r,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3.r,
          ),
        ),
        SizedBox(height: 3.r),
        Text(
          DateFormat('MMM dd yyyy · EEEE').format(now),
          style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r),
        ),
        SizedBox(height: 8.r),
        SizedBox(
          width: 250.r,
          height: 250.r,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final size in const [220.0, 190.0, 160.0, 130.0, 100.0])
                _dialRing(size),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3.r,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                child: InkWell(
                  onTap: _actionLoading || !canPunch
                      ? null
                      : showQr
                          ? () => context.push(AppRoutes.qrScanner)
                          : (open ? _clockOut : _clockIn),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 108.r,
                    height: 108.r,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        key: ValueKey(actionLabel),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_actionLoading)
                            SizedBox(
                              width: 22.r,
                              height: 22.r,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.r),
                            )
                          else
                            Icon(actionIcon,
                                color: AttendanceUi.accent, size: 24.r),
                          SizedBox(height: 7.r),
                          Text(
                            actionLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AttendanceUi.text,
                              fontSize: 12.r,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.r),
        _dailyMetrics(record),
      ],
    );
  }

  Widget _dialRing(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AttendanceUi.accent.withValues(alpha: 0.10),
          width: 1.2.r,
        ),
      ),
    );
  }

  AttendanceSessionModel? _todayRecord(DateTime now) {
    final candidates = _history.where((session) {
      final local = BranchTime.toBranch(
          session.clockInServerTime, session.branchTimezone ?? _branchTimezone);
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }).toList();
    if (_activeSession != null) {
      final activeLocal = BranchTime.toBranch(_activeSession!.clockInServerTime,
          _activeSession!.branchTimezone ?? _branchTimezone);
      if (activeLocal.year == now.year &&
          activeLocal.month == now.month &&
          activeLocal.day == now.day) {
        return _activeSession;
      }
    }
    if (candidates.isEmpty) return null;
    candidates
        .sort((a, b) => a.clockInServerTime.compareTo(b.clockInServerTime));
    return candidates.last;
  }

  Widget _dailyMetrics(AttendanceSessionModel? session) {
    final timezone = session?.branchTimezone ?? _branchTimezone;
    final checkIn = session == null
        ? '--:--'
        : DateFormat('hh:mm a')
            .format(BranchTime.toBranch(session.clockInServerTime, timezone));
    final checkOut = session?.clockOutServerTime == null
        ? '--:--'
        : DateFormat('hh:mm a').format(
            BranchTime.toBranch(session!.clockOutServerTime!, timezone));
    final total = session == null
        ? '--:--'
        : session.clockOutServerTime == null
            ? _liveDuration(session)
            : session.durationLabel;

    return Row(
      children: [
        _dailyMetric(Iconsax.login, 'Check in', checkIn),
        _dailyMetric(Iconsax.logout, 'Check out', checkOut),
        _dailyMetric(Iconsax.timer_1, 'Total hrs', total),
      ],
    );
  }

  Widget _dailyMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AttendanceUi.accent, size: 22.r),
          SizedBox(height: 5.r),
          Text(value,
              style: TextStyle(
                  color: AttendanceUi.muted,
                  fontSize: 10.r,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 3.r),
          Text(label,
              style: TextStyle(color: AttendanceUi.text, fontSize: 11.r)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _punchActionContent({
    required bool open,
    required bool attendanceEnabled,
  }) {
    final label = open
        ? 'Clock out'
        : attendanceEnabled
            ? 'Clock in'
            : 'Attendance not required';
    return Column(
      key: const ValueKey('punch_action'),
      children: [
        _actionIllustration(
          icon: open ? Iconsax.logout : Iconsax.login,
          title: open ? 'Finish your session' : 'Start your session',
          subtitle: open
              ? 'Submit your clock-out with the assigned policy.'
              : 'Use direct punch or scan the branch gate QR.',
        ),
        SizedBox(height: 14.r),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _actionLoading || (!open && !attendanceEnabled)
                ? null
                : (open ? _clockOut : _clockIn),
            icon: _actionLoading
                ? SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: CircularProgressIndicator(strokeWidth: 2.r))
                : Icon(open ? Icons.logout : Icons.login),
            label: Text(label),
            style: AttendanceUi.primaryButton().copyWith(
              minimumSize: WidgetStatePropertyAll(Size.fromHeight(48.r)),
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _qrActionContent() {
    return Column(
      key: const ValueKey('qr_action'),
      children: [
        _actionIllustration(
          icon: Icons.qr_code_scanner,
          title: 'Scan branch gate QR',
          subtitle: 'Use the permanent QR at the branch entrance.',
        ),
        SizedBox(height: 14.r),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _actionLoading ? null : () => context.push(AppRoutes.qrScanner),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR code'),
            style: AttendanceUi.primaryButton().copyWith(
              minimumSize: WidgetStatePropertyAll(Size.fromHeight(48.r)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionIllustration({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 54.r,
          height: 54.r,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border:
                Border.all(color: AttendanceUi.accent.withValues(alpha: .3)),
          ),
          child: Icon(icon, color: AttendanceUi.accent, size: 27.r),
        ),
        SizedBox(width: 12.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      TextStyle(fontSize: 15.r, fontWeight: FontWeight.w700)),
              SizedBox(height: 3.r),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r)),
            ],
          ),
        ),
        Row(
          children: [
            if (_requiresQrForCurrentAction) _promptDot(true),
          ],
        ),
      ],
    );
  }

  Widget _promptDot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: active ? 7.r : 5.r,
        height: active ? 7.r : 5.r,
        decoration: BoxDecoration(
          color: active ? AttendanceUi.accent : AttendanceUi.divider,
          shape: BoxShape.circle,
        ),
      );

  Widget _policyParameters() {
    final locationRequired = _policy['location_on_clock_in'] == true ||
        _policy['location_on_clock_out'] == true;
    final selfieRequired = _policy['selfie_on_clock_in'] == true ||
        _policy['selfie_on_clock_out'] == true;
    final geofenceEnabled = _policy['geofence_enabled'] == true;
    final qrRequired = _policy['qr_scan_on_clock_in'] == true ||
        _policy['qr_scan_on_clock_out'] == true;
    final grace = _policy['late_grace_minutes'] ?? 15;
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Policy applied to this punch',
            style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 12.r),
        Row(
          children: [
            _policyParameter(Icons.location_on_outlined, 'Location',
                locationRequired ? 'Required' : 'Optional', locationRequired),
            _policyParameter(Icons.camera_alt_outlined, 'Selfie',
                selfieRequired ? 'Required' : 'Optional', selfieRequired),
            _policyParameter(Icons.radar, 'Geofence',
                geofenceEnabled ? 'On' : 'Off', geofenceEnabled),
            _policyParameter(Icons.schedule, 'Late grace', '$grace min', false),
            _policyParameter(Icons.qr_code_scanner, 'QR scan',
                qrRequired ? 'Required' : 'Optional', qrRequired),
          ],
        ),
        if (_policy['shift_snapshot'] is Map) ...[
          SizedBox(height: 10.r),
          Text(
            'Shift: ${(_policy['shift_snapshot'] as Map)['name'] ?? 'Scheduled'} · ${(_policy['shift_snapshot'] as Map)['start_time'] ?? '--'}–${(_policy['shift_snapshot'] as Map)['end_time'] ?? '--'}',
            style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r),
          ),
        ],
      ],
    ));
  }

  Widget _policyParameter(
      IconData icon, String label, String value, bool emphasized) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 19.r,
              color: emphasized ? AttendanceUi.accent : AttendanceUi.muted),
          SizedBox(height: 5.r),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AttendanceUi.muted, fontSize: 9.r)),
          SizedBox(height: 2.r),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: emphasized ? AttendanceUi.accent : AttendanceUi.text,
                  fontSize: 9.r,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _todayStatusCard(bool open) {
    final localNow = BranchTime.toBranch(_clock, _branchTimezone);
    final title = open ? 'You are clocked in' : 'Ready for attendance';
    final subtitle = open
        ? 'Your current session is being tracked by the server.'
        : 'Start your session when you arrive at the branch.';
    final icon = open ? Iconsax.login : Iconsax.calendar_add;
    return _card(Row(
      children: [
        Container(
          width: 42.r,
          height: 42.r,
          decoration: BoxDecoration(
            color: AttendanceUi.accentTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AttendanceUi.accent, size: 20.r),
        ),
        SizedBox(width: 12.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 3.r),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r)),
            ],
          ),
        ),
        SizedBox(width: 8.r),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(DateFormat('hh:mm a').format(localNow),
                style: TextStyle(
                    color: AttendanceUi.text,
                    fontSize: 12.r,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 3.r),
            Text(
              _repository.hasServerTime ? 'Server time' : 'Syncing time',
              style: TextStyle(color: AttendanceUi.muted, fontSize: 9.r),
            ),
          ],
        ),
      ],
    ));
  }

  Widget _ongoingTimeline(AttendanceSessionModel session) {
    final timezone = session.branchTimezone ?? _branchTimezone;
    final clockIn = BranchTime.toBranch(session.clockInServerTime, timezone);
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Today\'s timeline',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 4.r),
              decoration: BoxDecoration(
                color: AttendanceUi.accentTint,
                borderRadius: BorderRadius.circular(5.r),
              ),
              child: Text(
                'ONGOING',
                style: TextStyle(
                  color: AttendanceUi.accent,
                  fontSize: 9.r,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.r),
        _timelinePoint(
          icon: Iconsax.login,
          title: 'Clocked in',
          subtitle: DateFormat('hh:mm a').format(clockIn),
          color: AttendanceUi.accent,
        ),
        Container(
          margin: EdgeInsets.only(left: 11.r),
          height: 18.r,
          width: 1.r,
          color: AttendanceUi.divider,
        ),
        _timelinePoint(
          icon: Iconsax.timer_1,
          title: 'In progress',
          subtitle: '${_liveDuration(session)} · awaiting clock-out',
          color: AttendanceUi.accent,
        ),
      ],
    ));
  }

  Widget _timelinePoint({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 24.r,
          height: 24.r,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13.r, color: color),
        ),
        SizedBox(width: 10.r),
        Expanded(
          child: Text(title,
              style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w700)),
        ),
        Text(subtitle,
            style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r)),
      ],
    );
  }

  String _liveDuration(AttendanceSessionModel session) {
    final minutes =
        _clock.toUtc().difference(session.clockInServerTime.toUtc()).inMinutes;
    final safeMinutes = minutes < 0 ? 0 : minutes;
    final hours = safeMinutes ~/ 60;
    final remaining = safeMinutes % 60;
    return hours > 0 ? '${hours}h ${remaining}m' : '${remaining}m';
  }

  // ignore: unused_element
  Widget _clockCard() =>
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            DateFormat('EEEE, dd MMM yyyy')
                .format(BranchTime.toBranch(_clock, _branchTimezone)),
            style: const TextStyle(color: AttendanceUi.muted)),
        SizedBox(height: 8.r),
        Text(
            DateFormat('hh:mm:ss a')
                .format(BranchTime.toBranch(_clock, _branchTimezone)),
            style: TextStyle(fontSize: 28.r, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.r),
        Text(
            '${_repository.hasServerTime ? 'Server-synchronized clock' : 'Device clock until server sync'} • server confirms every punch',
            style: TextStyle(color: AttendanceUi.muted, fontSize: 12.r)),
      ]));

  // ignore: unused_element
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
      if (_policy['qr_scan_on_clock_in'] == true ||
          _policy['qr_scan_on_clock_out'] == true)
        'QR scan required',
    ];
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Effective attendance policy',
          style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 10.r),
      Text(requirements.isEmpty
          ? 'No additional evidence required.'
          : requirements.join(' • ')),
      if (_policy['punch_required'] == false) ...[
        SizedBox(height: 8.r),
        const Text(
          'Attendance punching is disabled for this policy.',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: AttendanceUi.accent),
        ),
      ],
      SizedBox(height: 6.r),
      Text('Late grace: ${_policy['late_grace_minutes'] ?? 15} minutes',
          style: TextStyle(color: AttendanceUi.muted, fontSize: 12.r)),
      if (_policy['shift_snapshot'] is Map) ...[
        SizedBox(height: 6.r),
        Text(
            'Shift: ${(_policy['shift_snapshot'] as Map)['name'] ?? 'Scheduled'} (${(_policy['shift_snapshot'] as Map)['start_time'] ?? '--'}–${(_policy['shift_snapshot'] as Map)['end_time'] ?? '--'})',
            style: TextStyle(color: AttendanceUi.muted, fontSize: 12.r)),
      ],
      SizedBox(height: 4.r),
      Text(
          'Policy ${_policy['version'] ?? '-'} • ${_policy['source_scope'] ?? 'BRANCH_DEFAULT'}',
          style: TextStyle(color: AttendanceUi.muted, fontSize: 12.r)),
    ]));
  }

  // ignore: unused_element
  Widget _compactSessionCard(AttendanceSessionModel? session,
      {required bool open}) {
    if (session == null) {
      return _card(
        Row(
          children: [
            Icon(Icons.event_available, color: AttendanceUi.accent, size: 20.r),
            SizedBox(width: 10.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No open attendance session',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 3.r),
                  Text('Clock in when you begin your session.',
                      style:
                          TextStyle(color: AttendanceUi.muted, fontSize: 11.r)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final timezone = session.branchTimezone ?? _branchTimezone;
    final eventTime = BranchTime.toBranch(session.clockInServerTime, timezone);
    return DailioCompactTile(
      avatar: _sessionAvatar(session, AttendanceUi.accent, Iconsax.login),
      title: 'Current session',
      statusBadge: 'In progress',
      statusBadgeColor: AttendanceUi.accent,
      subtitle:
          'Clocked in at ${DateFormat('hh:mm a').format(eventTime)} · ${session.durationLabel}',
      trailing: DateFormat('dd MMM').format(eventTime),
      subtitleColor: AttendanceUi.accent,
      onTap: () => _openDetail(session),
      menuItems: const [
        DailioMenuItem(
          value: 'details',
          icon: Iconsax.document_text,
          label: 'View details',
        ),
      ],
      onMenuSelected: (_) => _openDetail(session),
    );
  }

  Widget _punchStatusCard() {
    final status = _punchStatus;
    final submitting = status == 'submitting';
    final confirmed = status == 'confirmed';
    final cancelled = status == 'cancelled';
    final color = submitting || confirmed || cancelled
        ? AttendanceUi.accent
        : AttendanceUi.text;
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
      SizedBox(width: 10.r),
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
        child:
            ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          SizedBox(height: 180.r),
          Center(child: Text('No attendance records for this period.')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 12.r, bottom: 96.r),
        itemCount: _history.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.r),
        itemBuilder: (_, index) {
          final session = _history[index];
          return _compactHistoryTile(session);
          /*
            onTap: () => _openDetail(session),
            borderRadius: BorderRadius.circular(14),
            child: _card(Row(children: [
              CircleAvatar(
                backgroundColor: session.state == 'OPEN'
                    ? AttendanceUi.accentTint
                    : AttendanceUi.divider,
                child: Icon(
                    session.state == 'OPEN' ? Icons.timelapse : Icons.check,
                    color: session.state == 'OPEN'
                        ? AttendanceUi.accent
                        : AttendanceUi.text),
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
                        style:
                            TextStyle(color: AttendanceUi.muted, fontSize: 12)),
                  ])),
              Text(session.durationLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          */
        },
      ),
    );
  }

  Widget _compactHistoryTile(AttendanceSessionModel session) {
    final timezone = session.branchTimezone ?? _branchTimezone;
    final clockIn = BranchTime.toBranch(session.clockInServerTime, timezone);
    final clockOut = session.clockOutServerTime == null
        ? null
        : BranchTime.toBranch(session.clockOutServerTime!, timezone);
    final open = clockOut == null;
    final isLate = session.derivedStatus == 'LATE';
    final statusColor =
        open || isLate ? AttendanceUi.accent : AttendanceUi.text;
    final statusIcon = open
        ? Iconsax.login
        : isLate
            ? Iconsax.clock
            : Iconsax.verify;
    final eventTime = clockOut ?? clockIn;
    final statusLabel = open
        ? 'In progress'
        : isLate
            ? 'Late'
            : 'Completed';

    return DailioCompactTile(
      avatar: _sessionAvatar(session, statusColor, statusIcon),
      title: session.memberName ?? 'You',
      titleBadge: session.memberRoleName,
      statusBadge: statusLabel,
      statusBadgeColor: statusColor,
      subtitle:
          '${open ? 'Clocked in at' : 'Clocked out at'} ${DateFormat('hh:mm a').format(eventTime)} · ${session.durationLabel}',
      trailing: DateFormat('dd MMM').format(clockIn),
      subtitleColor: statusColor,
      onTap: () => _openDetail(session),
      menuItems: const [
        DailioMenuItem(
          value: 'details',
          icon: Iconsax.document_text,
          label: 'View details',
        ),
      ],
      onMenuSelected: (_) => _openDetail(session),
    );
  }

  Widget _sessionAvatar(
      AttendanceSessionModel session, Color color, IconData icon) {
    final image = session.memberAvatar;
    final initials = session.memberName?.isNotEmpty == true
        ? session.memberName![0].toUpperCase()
        : 'Y';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24.r,
          backgroundColor: AttendanceUi.accentTint,
          backgroundImage:
              image == null || image.isEmpty ? null : NetworkImage(image),
          child: image == null || image.isEmpty
              ? Text(
                  initials,
                  style: const TextStyle(
                    color: AttendanceUi.accent,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        Positioned(
          right: (-2).r,
          bottom: (-2).r,
          child: Container(
            width: 18.r,
            height: 18.r,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.r),
            ),
            child: Icon(icon, size: 9.r, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _historyTile(AttendanceSessionModel session) {
    final timezone = session.branchTimezone ?? _branchTimezone;
    final clockIn = BranchTime.toBranch(session.clockInServerTime, timezone);
    final clockOut = session.clockOutServerTime == null
        ? null
        : BranchTime.toBranch(session.clockOutServerTime!, timezone);
    final open = clockOut == null;
    final statusColor = open ? AttendanceUi.accent : AttendanceUi.text;
    final statusIcon = open ? Iconsax.login : Iconsax.verify;
    final eventTime = clockOut ?? clockIn;
    final avatar = session.memberAvatar;
    final initials = session.memberName?.isNotEmpty == true
        ? session.memberName![0].toUpperCase()
        : 'Y';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(session),
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          decoration: AttendanceUi.cardDecoration(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.r, 12.r, 6.r, 12.r),
            child: Row(children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24.r,
                    backgroundColor: AttendanceUi.accentTint,
                    backgroundImage: avatar == null || avatar.isEmpty
                        ? null
                        : NetworkImage(avatar),
                    child: avatar == null || avatar.isEmpty
                        ? Text(initials,
                            style: const TextStyle(
                                color: AttendanceUi.accent,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  Positioned(
                    right: (-2).r,
                    bottom: (-2).r,
                    child: Container(
                      width: 18.r,
                      height: 18.r,
                      decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.r)),
                      child: Icon(statusIcon, size: 9.r, color: Colors.white),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEE, dd MMM yyyy').format(clockIn),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.r)),
                      SizedBox(height: 5.r),
                      Text(
                          '${open ? 'Clocked in at' : 'Clocked out at'} ${DateFormat('hh:mm a').format(eventTime)}',
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 12.r,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 3.r),
                      Text(
                          '${session.durationLabel}  •  ${open ? 'In progress' : 'Completed'}',
                          style: TextStyle(
                              color: AttendanceUi.muted, fontSize: 11.r)),
                    ]),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert,
                    size: 20.r, color: AttendanceUi.muted),
                onSelected: (_) => _openDetail(session),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'details', child: Text('View details')),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _historyFilter() => DailioTabStrip<String>(
        tabs: const [
          DailioTabItem(value: 'today', label: 'Today'),
          DailioTabItem(value: 'yesterday', label: 'Yesterday'),
          DailioTabItem(value: 'this_week', label: 'This week'),
          DailioTabItem(value: 'this_month', label: 'This month'),
          DailioTabItem(value: 'this_year', label: 'This year'),
        ],
        selected: _historyPeriod,
        centered: true,
        onChanged: _selectHistoryPeriod,
      );

  Future<void> _selectHistoryPeriod(String period) async {
    if (!mounted) return;
    setState(() => _historyPeriod = period);
    await _load();
  }

  void _openDetail(AttendanceSessionModel session) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AttendanceDetailPage(sessionId: session.id)));
  }

  Widget _card(Widget child) => Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AttendanceUi.divider),
        ),
        child: child,
      );

  String _newPunchKey() =>
      'mobile-attendance-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  bool get _requiresQrForCurrentAction {
    if (_activeSession != null) {
      return _policy['qr_scan_on_clock_out'] == true;
    }
    return _policy['qr_scan_on_clock_in'] == true;
  }
}
