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
    return MemberSubscription(
      id: json['id'],
      status: json['status'],
      startDate: DateTime.parse(json['start_date'] ?? json['startDate']),
      endDate: DateTime.parse(json['end_date'] ?? json['endDate']),
      planName: json['plan']?['name'] ?? 'Custom Plan',
      amountMinor:
          json['agreedAmountMinor'] ?? json['agreed_amount_minor'] ?? 0,
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
  final String? branchId;
  final String? subscriptionId;
  final String? shiftId;
  final String? salaryStructureId;
  final String? joinedAt;
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
    this.branchId,
    this.subscriptionId,
    this.shiftId,
    this.salaryStructureId,
    this.joinedAt,
    this.activeSubscription,
  });

  factory MemberModel.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    final roleJson = j['role'] as Map<String, dynamic>?;

    MemberSubscription? sub;
    final subs = j['subscriptions'] as List?;
    if (subs != null && subs.isNotEmpty) {
      sub = MemberSubscription.fromJson(subs.first);
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
      branchId: j['branch_id'],
      subscriptionId: j['subscription_id'],
      shiftId: j['shift_id'],
      salaryStructureId: j['salary_structure_id'],
      joinedAt: j['created_at'],
      activeSubscription: sub,
    );
  }

  String get fullName => name;
}
