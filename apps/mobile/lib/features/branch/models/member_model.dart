import '../../organization/models/role_model.dart';

class MemberSubscription {
  final String id;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String planName;
  final int amountMinor;

  MemberSubscription({
    required this.id,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.planName,
    required this.amountMinor,
  });

  factory MemberSubscription.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(
          (json['start_date'] ?? json['startDate'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final end = DateTime.tryParse(
          (json['end_date'] ?? json['endDate'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return MemberSubscription(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      startDate: start,
      endDate: end,
      planName: (json['plan'] as Map?)?['name']?.toString() ?? 'Custom Plan',
      amountMinor:
          (json['agreedAmountMinor'] ?? json['agreed_amount_minor'] ?? 0) is num
              ? ((json['agreedAmountMinor'] ?? json['agreed_amount_minor'] ?? 0)
                      as num)
                  .toInt()
              : 0,
    );
  }
}

class MemberModel {
  final String id;
  final String membershipNumber;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final String status; // ACTIVE | SUSPENDED | INACTIVE
  final RoleModel? role;
  final List<RoleModel> assignedRoles;
  final String? branchId;
  final String? subscriptionId;
  final String? shiftId;
  final String? managerMemberId;
  final String? salaryStructureId;
  final String? joinedAt;
  final List<MemberSubscription> subscriptions;
  final MemberSubscription? activeSubscription;

  MemberModel({
    required this.id,
    required this.membershipNumber,
    required this.name,
    this.email,
    this.avatarUrl,
    this.phone,
    required this.status,
    this.role,
    this.assignedRoles = const [],
    this.branchId,
    this.subscriptionId,
    this.shiftId,
    this.managerMemberId,
    this.salaryStructureId,
    this.joinedAt,
    this.subscriptions = const [],
    this.activeSubscription,
  });

  factory MemberModel.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    final roleJson = j['role'] as Map<String, dynamic>?;
    final assignmentJson = (j['role_assignments'] as List?) ?? const [];
    final assignedRoles = assignmentJson
        .whereType<Map>()
        .map((item) => item['role'] is Map
            ? RoleModel.fromJson(Map<String, dynamic>.from(item['role'] as Map))
            : null)
        .whereType<RoleModel>()
        .toList();

    final subscriptions = <MemberSubscription>[];
    final subs = j['subscriptions'] as List?;
    if (subs != null && subs.isNotEmpty) {
      subscriptions.addAll(
        subs
            .whereType<Map>()
            .map((item) =>
                MemberSubscription.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    return MemberModel(
      id: j['id'],
      membershipNumber: j['member_number'] ?? '',
      name: user['name'] ?? 'Unknown Member',
      email: user['email'],
      avatarUrl: user['avatar_url'],
      phone: user['phone'],
      status: j['status'] ?? 'ACTIVE',
      role: roleJson != null ? RoleModel.fromJson(roleJson) : null,
      assignedRoles: assignedRoles,
      branchId: j['branch_id'],
      subscriptionId: j['subscription_id'],
      shiftId: j['shift_id'],
      managerMemberId: j['manager_member_id']?.toString(),
      salaryStructureId: j['salary_structure_id'],
      joinedAt: j['created_at'],
      subscriptions: subscriptions,
      activeSubscription: subscriptions.isEmpty ? null : subscriptions.first,
    );
  }

  String get fullName => name;

  List<String> get roleIds => assignedRoles.isNotEmpty
      ? assignedRoles.map((role) => role.id).toList()
      : (role?.id == null ? const [] : [role!.id]);
}
