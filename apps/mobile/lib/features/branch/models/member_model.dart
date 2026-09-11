import '../../organization/models/role_model.dart';

class MemberModel {
  final String id;
  final String membershipNumber;
  final String name;
  final String? email;
  final String? phone;
  final String status; // ACTIVE | SUSPENDED | INACTIVE
  final RoleModel? role;
  final String? joinedAt;

  MemberModel(
      {required this.id,
      required this.membershipNumber,
      required this.name,
      this.email,
      this.phone,
      required this.status,
      this.role,
      this.joinedAt});

  factory MemberModel.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    final roleJson = j['role'] as Map<String, dynamic>?;

    return MemberModel(
      id: j['id'],
      membershipNumber: j['member_number'] ?? '',
      name: user['name'] ?? 'Unknown Member',
      email: user['email'],
      phone: user['phone'],
      status: j['status'] ?? 'ACTIVE',
      role: roleJson != null ? RoleModel.fromJson(roleJson) : null,
      joinedAt: j['created_at'],
    );
  }

  String get fullName => name;
}
