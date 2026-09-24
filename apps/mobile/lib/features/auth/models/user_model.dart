/// Plain Dart class — no code generation required.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.status,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.dateOfBirth,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String status;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? dateOfBirth;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';

  UserModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? dateOfBirth,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
