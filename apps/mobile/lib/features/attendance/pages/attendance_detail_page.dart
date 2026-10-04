import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/branch_time.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../attendance_error.dart';
import '../attendance_ui.dart';
import '../controllers/attendance_repository.dart';
import '../models/attendance_models.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AttendanceDetailPage extends StatefulWidget {
  final String sessionId;

  const AttendanceDetailPage({super.key, required this.sessionId});

  @override
  State<AttendanceDetailPage> createState() => _AttendanceDetailPageState();
}

class _AttendanceDetailPageState extends State<AttendanceDetailPage> {
  AttendanceSessionModel? _session;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) {
      setState(() {
        _error = 'Select an active branch first.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session =
          await context.read<AttendanceRepository>().getSessionDetail(
        branchId,
        widget.sessionId,
        onFresh: (freshSession) {
          if (mounted) setState(() => _session = freshSession);
        },
      );
      if (mounted) setState(() => _session = session);
    } catch (error) {
      if (mounted) setState(() => _error = attendanceErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
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
            icon: Iconsax.refresh,
            label: 'Refresh',
          ),
        ],
        onMenuSelected: (value) {
          if (value == 'refresh') _load();
        },
      ),
      body: _loading
          ? ShimmerLoader.detailPage()
          : _error != null
              ? _errorView()
              : _session == null
                  ? const Center(child: Text('Attendance record not found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.r, 20.r, 16.r, 96.r),
                        children: [
                          _identityHeader(_session!),
                          SizedBox(height: 22.r),
                          _sessionDial(_session!),
                          SizedBox(height: 28.r),
                          _activityTimeline(_session!),
                          SizedBox(height: 12.r),
                          _sessionContext(_session!),
                          SizedBox(height: 12.r),
                          _evidence(_session!),
                        ],
                      ),
                    ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.cloud_cross, size: 42.r, color: AttendanceUi.muted),
              SizedBox(height: 12.r),
              Text(_error!, textAlign: TextAlign.center),
              SizedBox(height: 12.r),
              OutlinedButton(
                onPressed: _load,
                style: AttendanceUi.outlinedButton(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );

  Widget _identityHeader(AttendanceSessionModel session) {
    final localDate = BranchTime.toBranch(
      session.clockInServerTime,
      session.branchTimezone,
    );
    final status = _statusLabel(session);
    final statusColor = _statusColor(session);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _avatar(session),
        SizedBox(width: 12.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      session.memberName ?? 'Attendance record',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.r,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (session.memberRoleName != null) ...[
                    SizedBox(width: 7.r),
                    _badge(session.memberRoleName!),
                  ],
                ],
              ),
              SizedBox(height: 3.r),
              Text(
                DateFormat('EEEE, dd MMM yyyy').format(localDate),
                style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r),
              ),
            ],
          ),
        ),
        _badge(status, color: statusColor),
      ],
    );
  }

  Widget _avatar(AttendanceSessionModel session) {
    final avatar = session.memberAvatar;
    final name = session.memberName?.trim() ?? 'A';
    final child = avatar != null && avatar.isNotEmpty
        ? CircleAvatar(
            radius: 25.r,
            backgroundColor: AttendanceUi.accentTint,
            backgroundImage: NetworkImage(avatar),
          )
        : CircleAvatar(
            radius: 25.r,
            backgroundColor: AttendanceUi.accentTint,
            foregroundColor: AttendanceUi.accent,
            child: Text(
              name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
    if (session.memberId == null) return child;
    return GestureDetector(
      onTap: () => showDailioMemberProfileSheet(
        context,
        DailioMemberPreview(
          memberId: session.memberId!,
          name: session.memberName ?? 'Member',
          role: session.memberRoleName ?? 'Member',
          status: session.state,
          avatarUrl: session.memberAvatar,
        ),
      ),
      child: child,
    );
  }

  Widget _sessionDial(AttendanceSessionModel session) {
    final timezone = session.branchTimezone;
    final clockIn = BranchTime.toBranch(session.clockInServerTime, timezone);
    final open = session.state == 'OPEN';
    final primaryColor = _statusColor(session);
    final centerIcon = open ? Iconsax.login : Iconsax.tick_circle;

    return Column(
      children: [
        Text(
          DateFormat('hh:mm a').format(clockIn),
          style: TextStyle(
            color: AttendanceUi.text,
            fontSize: 34.r,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3.r,
          ),
        ),
        SizedBox(height: 3.r),
        Text(
          open
              ? 'Clocked in · session ongoing'
              : 'Attendance session completed',
          style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r),
        ),
        SizedBox(height: 9.r),
        SizedBox(
          width: 236.r,
          height: 236.r,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final size in const [210.0, 180.0, 150.0, 120.0, 92.0])
                _dialRing(size, primaryColor),
              Container(
                width: 104.r,
                height: 104.r,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8.r,
                      spreadRadius: 1.r,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(centerIcon, color: primaryColor, size: 24.r),
                    SizedBox(height: 7.r),
                    Text(
                      open ? 'In progress' : 'Completed',
                      style: TextStyle(
                        color: AttendanceUi.text,
                        fontSize: 12.r,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.r),
        _metrics(session),
      ],
    );
  }

  Widget _dialRing(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.10), width: 1.2.r),
      ),
    );
  }

  Widget _metrics(AttendanceSessionModel session) {
    final timezone = session.branchTimezone;
    final clockOut = session.clockOutServerTime;
    final total =
        session.state == 'OPEN' ? 'In progress' : session.durationLabel;
    return Row(
      children: [
        _metric(
          Iconsax.login,
          'Check in',
          DateFormat('hh:mm a').format(
            BranchTime.toBranch(session.clockInServerTime, timezone),
          ),
        ),
        _metric(
          Iconsax.logout,
          'Check out',
          clockOut == null
              ? '--:--'
              : DateFormat('hh:mm a').format(
                  BranchTime.toBranch(clockOut, timezone),
                ),
        ),
        _metric(Iconsax.timer_1, 'Total hrs', total),
      ],
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AttendanceUi.accent, size: 22.r),
          SizedBox(height: 5.r),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AttendanceUi.muted,
              fontSize: 10.r,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.r),
          Text(label, style: TextStyle(fontSize: 11.r)),
        ],
      ),
    );
  }

  Widget _activityTimeline(AttendanceSessionModel session) {
    final activities = _activities(session);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Activity timeline',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _badge('${activities.length} events'),
            ],
          ),
          SizedBox(height: 14.r),
          if (activities.isEmpty)
            Text(
              'No activity has been recorded for this session.',
              style: TextStyle(color: AttendanceUi.muted, fontSize: 12.r),
            )
          else
            ...List.generate(
              activities.length,
              (index) => _activityRow(
                activities[index],
                session,
                isLast: index == activities.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _activityRow(
    AttendanceTimelineEventModel event,
    AttendanceSessionModel session, {
    required bool isLast,
  }) {
    final color = AttendanceUi.timelineColor(event.type);
    final source = event.source == null ? null : _pretty(event.source!);
    final status = event.status == null ? null : _pretty(event.status!);
    final detail = [
      if (status != null) status,
      if (source != null) source,
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30.r,
            child: Column(
              children: [
                Container(
                  width: 24.r,
                  height: 24.r,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(_timelineIcon(event.type), size: 13.r, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.r,
                      margin: EdgeInsets.symmetric(vertical: 3.r),
                      color: AttendanceUi.divider,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.r),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14.r),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timelineLabel(event.type),
                          style: TextStyle(
                            fontSize: 12.r,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (detail.isNotEmpty) ...[
                          SizedBox(height: 2.r),
                          Text(
                            detail,
                            style: TextStyle(
                              color: AttendanceUi.muted,
                              fontSize: 10.r,
                            ),
                          ),
                        ],
                        if (event.reason != null) ...[
                          SizedBox(height: 2.r),
                          Text(
                            event.reason!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AttendanceUi.muted,
                              fontSize: 10.r,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.r),
                  Text(
                    _time(event.at, session.branchTimezone),
                    style: TextStyle(
                      color: AttendanceUi.muted,
                      fontSize: 10.r,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<AttendanceTimelineEventModel> _activities(
    AttendanceSessionModel session,
  ) {
    if (session.timeline.isNotEmpty) {
      final events = [...session.timeline];
      events.sort((a, b) => a.at.compareTo(b.at));
      return events;
    }

    // Older API responses may not contain a prebuilt timeline. Keep the detail
    // screen complete by reconstructing the same activity sequence locally.
    final events = <AttendanceTimelineEventModel>[
      AttendanceTimelineEventModel(
        type: 'CLOCK_IN_CONFIRMED',
        at: session.clockInServerTime,
        status: 'CONFIRMED',
        source: session.source,
      ),
      ...session.evidence.where((item) => item.createdAt != null).map(
            (item) => AttendanceTimelineEventModel(
              type: item.type,
              at: item.createdAt!,
              status: 'ACCEPTED',
              evidenceId: item.id,
            ),
          ),
      if (session.clockOutServerTime != null)
        AttendanceTimelineEventModel(
          type: 'CLOCK_OUT_CONFIRMED',
          at: session.clockOutServerTime!,
          status: 'CONFIRMED',
          source: session.clockOutSource ?? session.source,
        ),
      if (session.correctedAt != null)
        AttendanceTimelineEventModel(
          type: 'CORRECTION_APPLIED',
          at: session.correctedAt!,
          status: 'CONFIRMED',
          reason: session.correctionReason,
        ),
    ];
    events.sort((a, b) => a.at.compareTo(b.at));
    return events;
  }

  Widget _sessionContext(AttendanceSessionModel session) {
    final variance = [
      if ((session.lateMinutes ?? 0) > 0) '${session.lateMinutes}m late',
      if ((session.earlyLeaveMinutes ?? 0) > 0)
        '${session.earlyLeaveMinutes}m early',
    ];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.r),
          Wrap(
            spacing: 7.r,
            runSpacing: 7.r,
            children: [
              _infoPill('Status', _statusLabel(session)),
              _infoPill('Source', _pretty(session.source ?? 'SELF')),
              if (session.policyVersion != null)
                _infoPill('Policy', 'v${session.policyVersion}'),
              if (variance.isNotEmpty)
                _infoPill('Variance', variance.join(' · ')),
            ],
          ),
          if (session.shiftName != null) ...[
            SizedBox(height: 9.r),
            Text(
              'Shift · ${session.shiftName} · ${session.shiftStartTime ?? '--'}–${session.shiftEndTime ?? '--'}',
              style: TextStyle(color: AttendanceUi.muted, fontSize: 11.r),
            ),
          ],
          if (session.branchTimezone != null) ...[
            SizedBox(height: 4.r),
            Text(
              'Branch time · ${session.branchTimezone}',
              style: TextStyle(color: AttendanceUi.muted, fontSize: 10.r),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 5.r),
      decoration: BoxDecoration(
        color: AttendanceUi.accentTint,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        '$label · $value',
        style: TextStyle(fontSize: 10.r, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _evidence(AttendanceSessionModel session) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evidence',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.r),
          if (session.evidence.isEmpty)
            Text(
              'No evidence was recorded for this session.',
              style: TextStyle(color: AttendanceUi.muted, fontSize: 12.r),
            )
          else
            ...List.generate(
              session.evidence.length,
              (index) => _evidenceRow(
                session,
                session.evidence[index],
                isLast: index == session.evidence.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _evidenceRow(
    AttendanceSessionModel session,
    AttendanceEvidenceModel item, {
    required bool isLast,
  }) {
    final isLocation = item.type.startsWith('LOCATION_');
    final canOpenLocation =
        isLocation && item.latitude != null && item.longitude != null;
    final canOpen = canOpenLocation || item.type.startsWith('SELFIE_');
    return InkWell(
      onTap: !canOpen
          ? null
          : canOpenLocation
              ? () => _openLocation(item)
              : () => _viewSelfie(session.id, item.id),
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 10.r),
        child: Row(
          children: [
            Icon(
              isLocation ? Iconsax.location : Iconsax.camera,
              color: AttendanceUi.accent,
              size: 19.r,
            ),
            SizedBox(width: 9.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pretty(item.type),
                    style: TextStyle(
                      fontSize: 12.r,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.r),
                  Text(
                    isLocation
                        ? item.accuracy == null
                            ? 'Location recorded'
                            : 'Accuracy ${item.accuracy!.toStringAsFixed(1)} m'
                        : 'Tap to preview authorized private evidence',
                    style: TextStyle(
                      color: AttendanceUi.muted,
                      fontSize: 10.r,
                    ),
                  ),
                ],
              ),
            ),
            if (item.createdAt != null)
              Text(
                _time(item.createdAt!, session.branchTimezone),
                style: TextStyle(color: AttendanceUi.muted, fontSize: 10.r),
              ),
            if (canOpen) ...[
              SizedBox(width: 6.r),
              Icon(
                Iconsax.arrow_right_3,
                color: AttendanceUi.muted,
                size: 15.r,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _viewSelfie(String sessionId, String evidenceId) async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) return;
    try {
      final result = await context
          .read<AttendanceRepository>()
          .getEvidenceDownloadUrl(branchId, sessionId, evidenceId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.all(16.r),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    result['url'].toString(),
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 320.r,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AttendanceUi.accent,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      height: 320.r,
                      child: Center(
                        child: Text(
                          'Evidence preview unavailable',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Iconsax.close_circle,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(attendanceErrorMessage(error))),
        );
      }
    }
  }

  Future<void> _openLocation(AttendanceEvidenceModel evidence) async {
    final latitude = evidence.latitude;
    final longitude = evidence.longitude;
    if (latitude == null || longitude == null) {
      _showEvidenceMessage('Location coordinates are unavailable.');
      return;
    }

    final mapsUri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '$latitude,$longitude',
      },
    );
    final opened = await launchUrl(
      mapsUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showEvidenceMessage('Google Maps could not be opened.');
    }
  }

  void _showEvidenceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _badge(String value, {Color? color}) {
    final badgeColor = color ?? AttendanceUi.softBlack;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 4.r),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: badgeColor,
          fontSize: 9.r,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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

  Color _statusColor(AttendanceSessionModel session) {
    if (session.state == 'OPEN') return AttendanceUi.accent;
    if (session.derivedStatus == 'INCOMPLETE' ||
        session.derivedStatus == 'LEFT_EARLY' ||
        (session.lateMinutes ?? 0) > 0) {
      return AttendanceUi.accent;
    }
    return AttendanceUi.softBlack;
  }

  String _statusLabel(AttendanceSessionModel session) {
    if (session.state == 'OPEN') return 'Ongoing';
    return _pretty(session.derivedStatus ?? 'COMPLETED');
  }

  IconData _timelineIcon(String type) {
    if (type.contains('CLOCK_IN')) return Iconsax.login;
    if (type.contains('CLOCK_OUT')) return Iconsax.logout;
    if (type.contains('SELFIE')) return Iconsax.camera;
    if (type.contains('LOCATION')) return Iconsax.location;
    if (type.contains('CORRECTION')) return Iconsax.edit;
    return Iconsax.tick_circle;
  }

  String _timelineLabel(String type) {
    switch (type) {
      case 'CLOCK_IN_CONFIRMED':
        return 'Clocked in';
      case 'CLOCK_OUT_CONFIRMED':
        return 'Clocked out';
      case 'SELFIE_IN':
        return 'Check-in selfie';
      case 'SELFIE_OUT':
        return 'Check-out selfie';
      case 'LOCATION_IN':
        return 'Check-in location';
      case 'LOCATION_OUT':
        return 'Check-out location';
      case 'CORRECTION_APPLIED':
        return 'Correction applied';
      default:
        return _pretty(type);
    }
  }

  String _pretty(String value) => value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  String _time(DateTime value, [String? timezone]) =>
      DateFormat('hh:mm a').format(BranchTime.toBranch(value, timezone));
}
