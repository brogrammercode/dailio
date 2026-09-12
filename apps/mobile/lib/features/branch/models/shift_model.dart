class ShiftModel {
  final String id;
  final String organizationId;
  final String branchId;
  final String name;
  final String startTime;
  final String endTime;
  final bool isOvernight;
  final int breakMinutes;
  final int graceInMin;
  final int graceOutMin;
  final List<int> weekDays;

  ShiftModel({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.isOvernight,
    required this.breakMinutes,
    required this.graceInMin,
    required this.graceOutMin,
    required this.weekDays,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'],
      organizationId: json['organization_id'],
      branchId: json['branch_id'],
      name: json['name'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      isOvernight: json['is_overnight'] ?? false,
      breakMinutes: json['break_minutes'] ?? 0,
      graceInMin: json['grace_in_min'] ?? 0,
      graceOutMin: json['grace_out_min'] ?? 0,
      weekDays: List<int>.from(json['week_days'] ?? []),
    );
  }
}
