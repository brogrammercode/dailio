class AttendanceSessionModel {
  final String id;
  final String state; // OPEN | CLOSED
  final String? derivedStatus;
  final DateTime clockInServerTime;
  final DateTime? clockOutServerTime;
  final int? workedMinutes;
  final String? memberName; // populated from includes

  AttendanceSessionModel(
      {required this.id,
      required this.state,
      this.derivedStatus,
      required this.clockInServerTime,
      this.clockOutServerTime,
      this.workedMinutes,
      this.memberName});

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> j) {
    final lm = j['location_membership'] as Map<String, dynamic>?;
    final om = lm?['organization_membership'] as Map<String, dynamic>?;
    return AttendanceSessionModel(
      id: j['id'],
      state: j['state'] ?? 'OPEN',
      derivedStatus: j['derived_status'],
      clockInServerTime: DateTime.parse(j['clock_in_server_time']),
      clockOutServerTime: j['clock_out_server_time'] != null
          ? DateTime.parse(j['clock_out_server_time'])
          : null,
      workedMinutes: j['worked_minutes'],
      memberName: om?['first_name'],
    );
  }

  String get durationLabel {
    if (workedMinutes == null) return 'In progress';
    final h = workedMinutes! ~/ 60;
    final m = workedMinutes! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
