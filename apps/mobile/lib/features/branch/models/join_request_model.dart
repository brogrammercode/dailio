class JoinRequestModel {
  final String id;
  final String userId;
  final String organizationId;
  final String locationId;
  final String status;
  final String? message;
  final RequestUserModel? user;

  JoinRequestModel({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.locationId,
    required this.status,
    this.message,
    this.user,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: json['id'],
      userId: json['user_id'],
      organizationId: json['organization_id'],
      locationId: json['location_id'],
      status: json['status'],
      message: json['message'],
      user:
          json['user'] != null ? RequestUserModel.fromJson(json['user']) : null,
    );
  }
}

class RequestUserModel {
  final String id;
  final String name;
  final String email;

  RequestUserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory RequestUserModel.fromJson(Map<String, dynamic> json) {
    return RequestUserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
