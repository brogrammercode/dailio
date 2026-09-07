class RoleModel {
  final String id;
  final String name;
  final String? systemKey;
  RoleModel({required this.id, required this.name, this.systemKey});
  factory RoleModel.fromJson(Map<String, dynamic> j) => RoleModel(
    id: j['id'], name: j['name'], systemKey: j['system_key']);
}

class MemberModel {
  final String id;            // location_membership id
  final String membershipNumber;
  final String firstName;
  final String? lastName;
  final String? email;
  final String status;        // ACTIVE | SUSPENDED | INACTIVE
  final List<RoleModel> roles;
  final String? joinedAt;

  MemberModel({required this.id, required this.membershipNumber, required this.firstName, this.lastName, this.email, required this.status, required this.roles, this.joinedAt});

  factory MemberModel.fromJson(Map<String, dynamic> j) {
    final orgMembership = j['organization_membership'] as Map<String, dynamic>? ?? {};
    final assignments = j['role_assignments'] as List? ?? [];
    return MemberModel(
      id: j['id'],
      membershipNumber: j['membership_number'] ?? '',
      firstName: orgMembership['first_name'] ?? '',
      lastName: orgMembership['last_name'],
      email: orgMembership['email'],
      status: j['status'] ?? 'ACTIVE',
      roles: assignments.map((a) {
        final role = a['role'] as Map<String, dynamic>? ?? {};
        return RoleModel.fromJson(role);
      }).toList(),
      joinedAt: j['joined_at'],
    );
  }

  String get fullName => [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
}
