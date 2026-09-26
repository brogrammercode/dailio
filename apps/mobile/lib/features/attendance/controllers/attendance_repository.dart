import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../models/attendance_models.dart';

class AttendanceRepository {
  final ApiClient apiClient;
  DateTime? _serverTime;
  DateTime? _serverTimeCapturedAt;

  AttendanceRepository({required this.apiClient});

  DateTime get serverNow {
    if (_serverTime == null || _serverTimeCapturedAt == null) {
      return DateTime.now();
    }
    return _serverTime!.add(DateTime.now().difference(_serverTimeCapturedAt!));
  }

  bool get hasServerTime => _serverTime != null;

  void _captureServerTime(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed != null) {
      _serverTime = parsed.toLocal();
      _serverTimeCapturedAt = DateTime.now();
    }
  }

  Future<AttendanceSessionModel> clockIn(
    String locationId, {
    required String idempotencyKey,
    int? policyVersion,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? selfieStorageKey,
    String? selfieUploadToken,
    String? selfieContentType,
    int? selfieSizeBytes,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$locationId/attendance/clock-in',
      data: {
        'idempotency_key': idempotencyKey,
        if (policyVersion != null) 'policy_version': policyVersion,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (selfieStorageKey != null) 'selfie_storage_key': selfieStorageKey,
        if (selfieUploadToken != null) 'selfie_upload_token': selfieUploadToken,
        if (selfieContentType != null) 'selfie_content_type': selfieContentType,
        if (selfieSizeBytes != null) 'selfie_size_bytes': selfieSizeBytes,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    _captureServerTime(response.data['server_time']);
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<AttendanceSessionModel> clockOut(
    String locationId,
    String sessionId, {
    required String idempotencyKey,
    int? policyVersion,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? selfieStorageKey,
    String? selfieUploadToken,
    String? selfieContentType,
    int? selfieSizeBytes,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$locationId/attendance/clock-out',
      data: {
        'session_id': sessionId,
        'idempotency_key': idempotencyKey,
        if (policyVersion != null) 'policy_version': policyVersion,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (selfieStorageKey != null) 'selfie_storage_key': selfieStorageKey,
        if (selfieUploadToken != null) 'selfie_upload_token': selfieUploadToken,
        if (selfieContentType != null) 'selfie_content_type': selfieContentType,
        if (selfieSizeBytes != null) 'selfie_size_bytes': selfieSizeBytes,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    _captureServerTime(response.data['server_time']);
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<AttendanceSessionModel?> getActiveSession(String locationId) async {
    final response = await apiClient.dio
        .get('/branches/$locationId/attendance/active-session');
    _captureServerTime(response.data['server_time']);
    if (response.data['session'] == null) return null;
    return AttendanceSessionModel.fromJson(response.data['session']);
  }

  Future<List<AttendanceSessionModel>> getSessions(
      String locationId, String period,
      {String? roleId, String? dateFrom, String? dateTo}) async {
    final page = await getSessionPage(
      locationId,
      period,
      roleId: roleId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    return page.sessions;
  }

  Future<AttendanceSessionPage> getSessionPage(String locationId, String period,
      {String? roleId,
      String? dateFrom,
      String? dateTo,
      String? cursor}) async {
    final response = await apiClient.dio.get(
      '/branches/$locationId/attendance',
      queryParameters: {
        'period': period,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        if (roleId != null) 'role_id': roleId,
        if (cursor != null) 'cursor': cursor,
      },
    );
    _captureServerTime(response.data['server_time']);
    final data = response.data['data'] as List? ?? [];
    return AttendanceSessionPage(
      sessions: data
          .map(
              (e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (response.data['meta'] as Map?)?['next_cursor']?.toString(),
    );
  }

  Future<String> exportSessions(String locationId, String period,
      {String? roleId}) async {
    final response = await apiClient.dio.get<String>(
      '/branches/$locationId/attendance/export',
      queryParameters: {
        'period': period,
        if (roleId != null) 'role_id': roleId,
      },
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  Future<Map<String, dynamic>> getAttendancePolicy(String locationId) async {
    final response =
        await apiClient.dio.get('/branches/$locationId/attendance/policy');
    _captureServerTime(response.data['server_time']);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadAttendanceSelfie(
      String locationId, XFile file) async {
    final signatureResponse = await apiClient.dio.post(
      '/branches/$locationId/attendance/evidence/upload-signature',
      data: {
        'filename': file.name,
        'content_type': 'image/jpeg',
      },
    );
    final signature =
        Map<String, dynamic>.from(signatureResponse.data['data'] as Map);
    final uploadData = <String, dynamic>{
      'api_key': signature['api_key'],
      'timestamp': signature['timestamp'].toString(),
      'signature': signature['signature'],
      'folder': signature['folder'],
      'public_id': signature['public_id'],
      'type': signature['type'],
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
    };
    final upload = await Dio().post(
      'https://api.cloudinary.com/v1_1/${signature['cloud_name']}/auto/upload',
      data: FormData.fromMap(uploadData),
    );
    return {
      'storage_key': signature['storage_key'],
      'upload_token': signature['upload_token'],
      'content_type': 'image/jpeg',
      'size_bytes': upload.data['bytes'],
    };
  }

  Future<List<Map<String, dynamic>>> getAttendancePolicies(
      String locationId) async {
    final response =
        await apiClient.dio.get('/branches/$locationId/attendance/policies');
    return ((response.data['data'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<AttendanceSessionModel> getSessionDetail(
      String locationId, String sessionId) async {
    final response =
        await apiClient.dio.get('/branches/$locationId/attendance/$sessionId');
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> getEvidenceDownloadUrl(
      String locationId, String sessionId, String evidenceId) async {
    final response = await apiClient.dio.get(
      '/branches/$locationId/attendance/$sessionId/evidence/$evidenceId/download',
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateAttendancePolicy(
      String locationId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .patch('/branches/$locationId/attendance/policy', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<AttendanceSessionModel> qrPunch(
    String token, {
    required String idempotencyKey,
    int? policyVersion,
    String? clientTime,
    String timezone = 'Asia/Kolkata',
    double? latitude,
    double? longitude,
    double? accuracy,
    String? selfieStorageKey,
    String? selfieUploadToken,
    String? selfieContentType,
    int? selfieSizeBytes,
  }) async {
    final response = await apiClient.dio.post(
      '/attendance/qr-punch',
      data: {
        'token': token,
        if (policyVersion != null) 'policy_version': policyVersion,
        'timezone': timezone,
        if (clientTime != null) 'client_time': clientTime,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (selfieStorageKey != null) 'selfie_storage_key': selfieStorageKey,
        if (selfieUploadToken != null) 'selfie_upload_token': selfieUploadToken,
        if (selfieContentType != null) 'selfie_content_type': selfieContentType,
        if (selfieSizeBytes != null) 'selfie_size_bytes': selfieSizeBytes,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    _captureServerTime(response.data['server_time']);
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> correctSession(
      String locationId, String sessionId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
        '/branches/$locationId/attendance/$sessionId/correct',
        data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<AttendanceSessionModel> createManualSession(
    String locationId, {
    required String memberId,
    required DateTime clockInAt,
    DateTime? clockOutAt,
    int? policyVersion,
    required String reason,
  }) async {
    final idempotencyKey =
        'manual-attendance-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final response = await apiClient.dio.post(
      '/branches/$locationId/attendance/manual',
      data: {
        'member_id': memberId,
        'clock_in_at': clockInAt.toUtc().toIso8601String(),
        if (clockOutAt != null)
          'clock_out_at': clockOutAt.toUtc().toIso8601String(),
        if (policyVersion != null) 'policy_version': policyVersion,
        'reason': reason,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    _captureServerTime(response.data['server_time']);
    return AttendanceSessionModel.fromJson(response.data['data']);
  }
}
