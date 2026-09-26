class AttendanceEvidenceModel {
  final String id;
  final String type;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? geofenceDistanceMeters;
  final DateTime? createdAt;

  const AttendanceEvidenceModel({
    required this.id,
    required this.type,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.geofenceDistanceMeters,
    this.createdAt,
  });

  factory AttendanceEvidenceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceEvidenceModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'UNKNOWN',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      geofenceDistanceMeters:
          (json['geofence_distance_meters'] as num?)?.toDouble(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class AttendanceTimelineEventModel {
  final String type;
  final DateTime at;
  final String? status;
  final String? source;
  final String? evidenceId;
  final int? version;
  final String? reason;

  const AttendanceTimelineEventModel({
    required this.type,
    required this.at,
    this.status,
    this.source,
    this.evidenceId,
    this.version,
    this.reason,
  });

  factory AttendanceTimelineEventModel.fromJson(Map<String, dynamic> json) {
    return AttendanceTimelineEventModel(
      type: json['type']?.toString() ?? 'UNKNOWN',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString(),
      source: json['source']?.toString(),
      evidenceId: json['evidence_id']?.toString(),
      version: (json['version'] as num?)?.toInt(),
      reason: json['reason']?.toString(),
    );
  }
}

class AttendanceSessionModel {
  final String id;
  final String state; // OPEN | CLOSED
  final String? derivedStatus;
  final DateTime clockInServerTime;
  final DateTime? clockOutServerTime;
  final int? workedMinutes;
  final String? memberName; // populated from includes
  final String? memberAvatar; // populated from includes
  final String? memberRoleName; // populated from includes
  final int? lateMinutes;
  final int? earlyLeaveMinutes;
  final String? shiftName;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final bool shiftOvernight;
  final int? breakMinutes;
  final int? policyVersion;
  final String? source;
  final String? clockOutSource;
  final String? branchTimezone;
  final String? correctionReason;
  final DateTime? correctedAt;
  final List<AttendanceEvidenceModel> evidence;
  final List<AttendanceTimelineEventModel> timeline;

  AttendanceSessionModel(
      {required this.id,
      required this.state,
      this.derivedStatus,
      required this.clockInServerTime,
      this.clockOutServerTime,
      this.workedMinutes,
      this.memberName,
      this.memberAvatar,
      this.memberRoleName,
      this.lateMinutes,
      this.earlyLeaveMinutes,
      this.shiftName,
      this.shiftStartTime,
      this.shiftEndTime,
      this.shiftOvernight = false,
      this.breakMinutes,
      this.policyVersion,
      this.source,
      this.clockOutSource,
      this.branchTimezone,
      this.correctionReason,
      this.correctedAt,
      this.evidence = const [],
      this.timeline = const []});

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> j) {
    final member = j['member'] as Map<String, dynamic>?;
    final user = member?['user'] as Map<String, dynamic>?;
    final snapshot = j['shift_snapshot'] is Map
        ? Map<String, dynamic>.from(j['shift_snapshot'] as Map)
        : const <String, dynamic>{};
    return AttendanceSessionModel(
      id: j['id'] ?? '',
      state: j['state'] ?? 'OPEN',
      derivedStatus: j['derived_status'],
      clockInServerTime:
          DateTime.parse(j['clock_in_at'] ?? DateTime.now().toIso8601String()),
      clockOutServerTime:
          j['clock_out_at'] != null ? DateTime.parse(j['clock_out_at']) : null,
      workedMinutes: j['worked_minutes'],
      memberName: user?['name'],
      memberAvatar: user?['avatar_url'],
      memberRoleName:
          (member?['role'] as Map<String, dynamic>?)?['name']?.toString(),
      lateMinutes: (j['late_minutes'] as num?)?.toInt(),
      earlyLeaveMinutes: (j['early_leave_minutes'] as num?)?.toInt(),
      shiftName: snapshot['name']?.toString(),
      shiftStartTime: snapshot['start_time']?.toString(),
      shiftEndTime: snapshot['end_time']?.toString(),
      shiftOvernight: snapshot['is_overnight'] == true,
      breakMinutes: (snapshot['break_minutes'] as num?)?.toInt(),
      policyVersion: (j['policy_version'] as num?)?.toInt(),
      source: j['source']?.toString(),
      clockOutSource: j['clock_out_source']?.toString(),
      branchTimezone: j['branch_timezone']?.toString(),
      correctionReason: j['correction_reason']?.toString(),
      correctedAt: j['corrected_at'] == null
          ? null
          : DateTime.tryParse(j['corrected_at'].toString()),
      evidence: ((j['evidence'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              AttendanceEvidenceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      timeline: ((j['timeline'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AttendanceTimelineEventModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  bool get hasLocationEvidence =>
      evidence.any((item) => item.type.startsWith('LOCATION_'));

  bool get hasSelfieEvidence =>
      evidence.any((item) => item.type.startsWith('SELFIE_'));

  String get durationLabel {
    if (workedMinutes == null) return 'In progress';
    final h = workedMinutes! ~/ 60;
    final m = workedMinutes! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class AttendanceSessionPage {
  final List<AttendanceSessionModel> sessions;
  final String? nextCursor;

  const AttendanceSessionPage({
    required this.sessions,
    this.nextCursor,
  });
}
