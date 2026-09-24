class AttendanceSessionModel {
  final String id;
  final String state; // OPEN | CLOSED
  final String? derivedStatus;
  final DateTime clockInServerTime;
  final DateTime? clockOutServerTime;
  final int? workedMinutes;
  final String? memberName; // populated from includes
  final String? memberAvatar; // populated from includes

  AttendanceSessionModel(
      {required this.id,
      required this.state,
      this.derivedStatus,
      required this.clockInServerTime,
      this.clockOutServerTime,
      this.workedMinutes,
      this.memberName,
      this.memberAvatar});

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> j) {
    final member = j['member'] as Map<String, dynamic>?;
    final user = member?['user'] as Map<String, dynamic>?;
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
    );
  }

  String get durationLabel {
    if (workedMinutes == null) return 'In progress';
    final h = workedMinutes! ~/ 60;
    final m = workedMinutes! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
