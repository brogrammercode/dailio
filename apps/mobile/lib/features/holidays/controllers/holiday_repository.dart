import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';

class HolidayRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  HolidayRepository({required this.apiClient, this.cache});

  Future<List<Map<String, dynamic>>> listHolidays(
    String branchId, {
    void Function(List<Map<String, dynamic>> fresh)? onFresh,
  }) async {
    final key = cache?.scopedKey('holidays:$branchId');
    Future<dynamic> fetch() async =>
        (await apiClient.dio.get('/branches/$branchId/holidays')).data;
    if (cache == null) {
      final response = await fetch();
      return _decode(response);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: key!,
      scope: 'branch:$branchId',
      fetch: fetch,
      decode: (payload) => _decode(payload),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> createHoliday(
    String branchId,
    Map<String, dynamic> data,
  ) async {
    final response =
        await apiClient.dio.post('/branches/$branchId/holidays', data: data);
    await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateHoliday(
    String branchId,
    String holidayId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.dio.patch(
      '/branches/$branchId/holidays/$holidayId',
      data: data,
    );
    await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<void> deleteHoliday(String branchId, String holidayId) async {
    await apiClient.dio.delete('/branches/$branchId/holidays/$holidayId');
    await cache?.clearScope('branch:$branchId');
  }

  static List<Map<String, dynamic>> _decode(dynamic payload) {
    final raw = payload is Map ? payload['data'] : payload;
    return List<Map<String, dynamic>>.from(
      (raw as List).map((item) => Map<String, dynamic>.from(item as Map)),
    );
  }
}
