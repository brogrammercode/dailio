/// Plain Dart class — no code generation required.
/// Convert to @freezed after running build_runner if richer functionality is needed.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    required this.status,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String status;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String,
    );
  }

  bool get isActive => status == 'ACTIVE';
}
