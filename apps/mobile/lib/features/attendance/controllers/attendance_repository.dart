import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/storage/json_cache_store.dart';
import '../models/attendance_models.dart';

class AttendanceRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;
  DateTime? _serverTime;
  DateTime? _serverTimeCapturedAt;

  AttendanceRepository({required this.apiClient, this.cache});

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
    // A confirmed clock-out ends the current session and intentionally resets
    // the local read-model cache. The next authenticated visit rebuilds it
    // from the server one page at a time.
    await cache?.clearAll();
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  Future<AttendanceSessionModel?> getActiveSession(String locationId,
      {void Function(AttendanceSessionModel?)? onFresh}) async {
    AttendanceSessionModel? decode(dynamic payload) {
      _captureServerTime((payload as Map)['server_time']);
      final session = payload['session'];
      return session == null
          ? null
          : AttendanceSessionModel.fromJson(
              Map<String, dynamic>.from(session as Map));
    }

    if (cache == null) {
      final response = await apiClient.dio
          .get('/branches/$locationId/attendance/active-session');
      return decode(response.data);
    }
    return cache!.load<AttendanceSessionModel?>(
      key: cache!.scopedKey('attendance-active:$locationId'),
      scope: 'branch:$locationId',
      fetch: () async => (await apiClient.dio
              .get('/branches/$locationId/attendance/active-session'))
          .data,
      decode: decode,
      cacheTransform: _safeAttendancePayload,
      onFresh: onFresh,
    );
  }

  Future<List<AttendanceSessionModel>> getSessions(
      String locationId, String period,
      {String? roleId,
      String? dateFrom,
      String? dateTo,
      void Function(List<AttendanceSessionModel> freshSessions)?
          onFresh}) async {
    final page = await getSessionPage(
      locationId,
      period,
      roleId: roleId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      onFresh: (page) => onFresh?.call(page.sessions),
    );
    return page.sessions;
  }

  Future<AttendanceSessionPage> getSessionPage(String locationId, String period,
      {String? roleId,
      String? dateFrom,
      String? dateTo,
      String? cursor,
      void Function(AttendanceSessionPage freshPage)? onFresh}) async {
    final query = <String, dynamic>{
      'period': period,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (roleId != null) 'role_id': roleId,
      if (cursor != null) 'cursor': cursor,
    };
    AttendanceSessionPage decode(dynamic payload) {
      final map = payload as Map;
      _captureServerTime(map['server_time']);
      final data = map['data'] as List? ?? [];
      return AttendanceSessionPage(
        sessions: data
            .map((e) => AttendanceSessionModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: (map['meta'] as Map?)?['next_cursor']?.toString(),
      );
    }

    if (cache == null) {
      final response = await apiClient.dio.get(
        '/branches/$locationId/attendance',
        queryParameters: query,
      );
      return decode(response.data);
    }
    final key =
        'attendance:$locationId:${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return cache!.load<AttendanceSessionPage>(
      key: cache!.scopedKey(key),
      scope: 'branch:$locationId',
      fetch: () async => (await apiClient.dio.get(
        '/branches/$locationId/attendance',
        queryParameters: query,
      ))
          .data,
      decode: decode,
      cacheTransform: _safeAttendancePayload,
      onFresh: onFresh,
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

  Future<Map<String, dynamic>> getAttendancePolicy(String locationId,
      {void Function(Map<String, dynamic> freshPolicy)? onFresh}) async {
    if (cache == null) {
      final response =
          await apiClient.dio.get('/branches/$locationId/attendance/policy');
      _captureServerTime(response.data['server_time']);
      return response.data['data'] as Map<String, dynamic>;
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey('attendance-policy:$locationId'),
      scope: 'branch:$locationId',
      fetch: () async =>
          (await apiClient.dio.get('/branches/$locationId/attendance/policy'))
              .data,
      decode: (payload) =>
          Map<String, dynamic>.from((payload as Map)['data'] as Map),
      onFresh: onFresh,
    );
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
    final uploadDio = Dio()..interceptors.add(LoggingInterceptor());
    final upload = await uploadDio.post(
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

  Future<List<Map<String, dynamic>>> getAttendancePolicies(String locationId,
      {void Function(List<Map<String, dynamic>> freshPolicies)?
          onFresh}) async {
    List<Map<String, dynamic>> decode(dynamic payload) =>
        ((payload as Map)['data'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    if (cache == null) {
      final response =
          await apiClient.dio.get('/branches/$locationId/attendance/policies');
      return decode(response.data);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('attendance-policies:$locationId'),
      scope: 'branch:$locationId',
      fetch: () async =>
          (await apiClient.dio.get('/branches/$locationId/attendance/policies'))
              .data,
      decode: decode,
      onFresh: onFresh,
    );
  }

  Future<AttendanceSessionModel> getSessionDetail(
      String locationId, String sessionId,
      {void Function(AttendanceSessionModel freshSession)? onFresh}) async {
    if (cache == null) {
      final response = await apiClient.dio
          .get('/branches/$locationId/attendance/$sessionId');
      return AttendanceSessionModel.fromJson(response.data['data']);
    }
    return cache!.load<AttendanceSessionModel>(
      key: cache!.scopedKey('attendance-detail:$locationId:$sessionId'),
      scope: 'branch:$locationId',
      fetch: () async => (await apiClient.dio
              .get('/branches/$locationId/attendance/$sessionId'))
          .data,
      decode: (payload) => AttendanceSessionModel.fromJson(
          Map<String, dynamic>.from((payload as Map)['data'] as Map)),
      cacheTransform: _safeAttendancePayload,
      onFresh: onFresh,
    );
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
    await cache?.clearScope('branch:$locationId');
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
    final session = AttendanceSessionModel.fromJson(response.data['data']);
    if (session.state == 'CLOSED') await cache?.clearAll();
    return session;
  }

  Future<Map<String, dynamic>> correctSession(
      String locationId, String sessionId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
        '/branches/$locationId/attendance/$sessionId/correct',
        data: data);
    await cache?.clearScope('branch:$locationId');
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
    await cache?.clearScope('branch:$locationId');
    return AttendanceSessionModel.fromJson(response.data['data']);
  }

  dynamic _safeAttendancePayload(dynamic value) {
    if (value is List) return value.map(_safeAttendancePayload).toList();
    if (value is Map) {
      final copy = <String, dynamic>{};
      value.forEach((key, item) {
        final name = key.toString();
        if (name == 'evidence' ||
            name == 'selfie_storage_key' ||
            name == 'selfie_upload_token') {
          return;
        }
        copy[name] = _safeAttendancePayload(item);
      });
      return copy;
    }
    return value;
  }
}
