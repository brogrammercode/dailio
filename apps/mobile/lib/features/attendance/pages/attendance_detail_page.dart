import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/branch_time.dart';
import '../controllers/attendance_repository.dart';
import '../attendance_error.dart';
import '../models/attendance_models.dart';

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
    try {
      final session = await context
          .read<AttendanceRepository>()
          .getSessionDetail(branchId, widget.sessionId);
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Attendance details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : _session == null
                  ? const Center(child: Text('Attendance record not found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _summary(_session!),
                          const SizedBox(height: 12),
                          _timeline(_session!),
                          const SizedBox(height: 12),
                          _evidence(_session!),
                        ],
                      ),
                    ),
    );
  }

  Widget _summary(AttendanceSessionModel session) {
    final date = DateFormat('EEEE, dd MMM yyyy').format(
        BranchTime.toBranch(session.clockInServerTime, session.branchTimezone));
    final color = session.state == 'OPEN' ? Colors.orange : Colors.green;
    return _card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(date,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))),
          Chip(
            label: Text(session.state),
            labelStyle: TextStyle(color: color.shade700, fontSize: 11),
            backgroundColor: color.shade50,
            side: BorderSide.none,
          ),
        ]),
        if (session.memberName != null) ...[
          const SizedBox(height: 4),
          Text(session.memberName!,
              style: TextStyle(color: Colors.grey.shade700)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _value('Clock in',
                  _time(session.clockInServerTime, session.branchTimezone))),
          Expanded(
              child: _value(
                  'Clock out',
                  session.clockOutServerTime == null
                      ? 'Open'
                      : _time(session.clockOutServerTime!,
                          session.branchTimezone))),
          Expanded(child: _value('Duration', session.durationLabel)),
        ]),
        const SizedBox(height: 12),
        Text('Status: ${session.derivedStatus ?? 'OPEN'}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
            'Source: ${session.source ?? 'SELF'}${session.clockOutSource == null ? '' : ' → ${session.clockOutSource}'}',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        if (session.branchTimezone != null)
          Text('Branch timezone: ${session.branchTimezone}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        if ((session.lateMinutes ?? 0) > 0 ||
            (session.earlyLeaveMinutes ?? 0) > 0)
          Text(
              'Variance: ${session.lateMinutes ?? 0}m late • ${session.earlyLeaveMinutes ?? 0}m early',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
        if (session.shiftName != null)
          Text(
              'Shift: ${session.shiftName} (${session.shiftStartTime ?? '--'}–${session.shiftEndTime ?? '--'})',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        if (session.correctionReason != null) ...[
          const SizedBox(height: 8),
          Text('Correction reason: ${session.correctionReason}',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _timeline(AttendanceSessionModel session) {
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Timeline',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 12),
      if (session.timeline.isEmpty)
        const Text('No server timeline events are available.')
      else
        ...session.timeline.map((entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(_timelineIcon(entry.type),
                      size: 16, color: Colors.indigo)),
              title: Text(_timelineLabel(entry.type),
                  style: const TextStyle(fontSize: 13)),
              subtitle: entry.reason == null
                  ? null
                  : Text(entry.reason!, maxLines: 2),
              trailing: Text(_time(entry.at, session.branchTimezone),
                  style: const TextStyle(fontSize: 12)),
            )),
    ]));
  }

  IconData _timelineIcon(String type) {
    if (type.contains('CLOCK_IN')) return Icons.login;
    if (type.contains('CLOCK_OUT')) return Icons.logout;
    if (type.contains('SELFIE')) return Icons.camera_alt_outlined;
    if (type.contains('LOCATION')) return Icons.location_on_outlined;
    if (type.contains('CORRECTION')) return Icons.edit_calendar;
    return Icons.check_circle_outline;
  }

  String _timelineLabel(String type) => type
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  Widget _evidence(AttendanceSessionModel session) {
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Evidence',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      if (session.evidence.isEmpty)
        Text('No evidence was recorded for this session.',
            style: TextStyle(color: Colors.grey.shade700))
      else
        ...session.evidence.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: item.type.startsWith('SELFIE_')
                  ? () => _viewSelfie(session.id, item.id)
                  : null,
              leading: Icon(item.type.startsWith('LOCATION_')
                  ? Icons.location_on_outlined
                  : Icons.camera_alt_outlined),
              title: Text(item.type.replaceAll('_', ' ')),
              subtitle: Text(item.type.startsWith('SELFIE_')
                  ? 'Tap to view authorized private evidence'
                  : item.accuracy == null
                      ? 'Recorded evidence'
                      : 'Accuracy ${item.accuracy!.toStringAsFixed(1)} m${item.geofenceDistanceMeters == null ? '' : ' • ${item.geofenceDistanceMeters!.toStringAsFixed(1)} m from geofence center'}'),
              trailing: item.createdAt == null
                  ? null
                  : Text(_time(item.createdAt!, session.branchTimezone),
                      style: const TextStyle(fontSize: 11)),
            )),
    ]));
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
          child: InteractiveViewer(
            child: Image.network(result['url'].toString(), fit: BoxFit.contain),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(attendanceErrorMessage(error))));
      }
    }
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

  Widget _value(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );

  String _time(DateTime value, [String? timezone]) =>
      DateFormat('dd MMM, hh:mm a')
          .format(BranchTime.toBranch(value, timezone));
}
