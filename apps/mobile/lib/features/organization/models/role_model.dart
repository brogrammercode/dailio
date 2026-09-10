class RoleModel {
  final String id;
  final String organizationId;
  final String name;
  final String? systemKey;
  final bool isProtected;
  final bool isSystem;
  final List<String> permissions;

  RoleModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.systemKey,
    required this.isProtected,
    required this.isSystem,
    required this.permissions,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      systemKey: json['system_key'],
      isProtected: json['is_protected'] ?? false,
      isSystem: json['is_system'] ?? false,
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'system_key': systemKey,
      'is_protected': isProtected,
      'is_system': isSystem,
      'permissions': permissions,
    };
  }
}
