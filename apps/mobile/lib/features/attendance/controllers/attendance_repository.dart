import '../../../core/network/api_client.dart';
import '../models/attendance_models.dart';

class AttendanceRepository {
  final ApiClient apiClient;

  AttendanceRepository({required this.apiClient});

  Future<AttendanceSessionModel> clockIn(String locationId) async {
    final response = await apiClient.dio.post(
      '/locations/$locationId/attendance/clock-in',
      data: {'timezone': 'Asia/Kolkata'},
    );
    return AttendanceSessionModel.fromJson(response.data['session']);
  }

  Future<AttendanceSessionModel> clockOut(
      String locationId, String sessionId) async {
    final response = await apiClient.dio.post(
      '/locations/$locationId/attendance/clock-out',
      data: {'session_id': sessionId, 'timezone': 'Asia/Kolkata'},
    );
    return AttendanceSessionModel.fromJson(response.data['session']);
  }

  Future<AttendanceSessionModel?> getActiveSession(String locationId) async {
    final response = await apiClient.dio
        .get('/locations/$locationId/attendance/active-session');
    if (response.data['session'] == null) return null;
    return AttendanceSessionModel.fromJson(response.data['session']);
  }

  Future<List<AttendanceSessionModel>> getSessions(
      String locationId, String period) async {
    final response = await apiClient.dio.get(
      '/locations/$locationId/attendance',
      queryParameters: {'period': period},
    );
    final data = response.data['data'] as List? ?? [];
    return data
        .map((e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
