class JoinRequestModel {
  final String id;
  final String userId;
  final String organizationId;
  final String branchId;
  final String status;
  final String? message;
  final RequestUserModel? user;

  JoinRequestModel({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.branchId,
    required this.status,
    this.message,
    this.user,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: json['id'],
      userId: json['user_id'],
      organizationId: json['organization_id'],
      branchId: json['branch_id'],
      status: json['status'],
      message: json['message'],
      user: json['user'] != null ? RequestUserModel.fromJson(json['user']) : null,
    );
  }
}

class RequestUserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  RequestUserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory RequestUserModel.fromJson(Map<String, dynamic> json) {
    return RequestUserModel(
      id: json['id'],
      name: json['name'] ?? 'Unknown User',
      email: json['email'],
      phone: json['phone'],
    );
  }
}

