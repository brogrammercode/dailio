import '../../../core/network/api_client.dart';
import '../models/attendance_models.dart';

class AttendanceRepository {
  final ApiClient apiClient;

  AttendanceRepository({required this.apiClient});

  Future<AttendanceSessionModel> clockIn(
    String locationId, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$locationId/attendance/clock-in',
      data: {
        'timezone': 'Asia/Kolkata',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<AttendanceSessionModel> clockOut(
    String locationId,
    String sessionId, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$locationId/attendance/clock-out',
      data: {
        'session_id': sessionId,
        'timezone': 'Asia/Kolkata',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<AttendanceSessionModel?> getActiveSession(String locationId) async {
    final response = await apiClient.dio
        .get('/branches/$locationId/attendance/active-session');
    if (response.data['session'] == null) return null;
    return AttendanceSessionModel.fromJson(response.data['session']);
  }

  Future<List<AttendanceSessionModel>> getSessions(
      String locationId, String period,
      {String? roleId}) async {
    final response = await apiClient.dio.get(
      '/branches/$locationId/attendance',
      queryParameters: {
        'period': period,
        if (roleId != null) 'role_id': roleId
      },
    );
    final data = response.data['data'] as List? ?? [];
    return data
        .map((e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getAttendancePolicy(String locationId) async {
    final response =
        await apiClient.dio.get('/branches/$locationId/attendance/policy');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAttendancePolicy(
      String locationId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .patch('/branches/$locationId/attendance/policy', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> correctSession(
      String locationId, String sessionId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
        '/branches/$locationId/attendance/$sessionId/correct',
        data: data);
    return response.data['data'] as Map<String, dynamic>;
  }
}
