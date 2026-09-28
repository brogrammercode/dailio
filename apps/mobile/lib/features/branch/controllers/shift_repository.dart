import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';

class ShiftRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  ShiftRepository(this.apiClient, {this.cache});

  Future<List<Map<String, dynamic>>> listShifts(String orgId,
      {String? branchId,
      void Function(List<Map<String, dynamic>> freshShifts)? onFresh}) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;
    if (cache == null) {
      final response = await apiClient.dio.get(
        '/organizations/$orgId/shifts',
        queryParameters: query,
      );
      return List<Map<String, dynamic>>.from(response.data);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('shifts:$orgId:${branchId ?? 'all'}'),
      scope: branchId == null ? 'organization:$orgId' : 'branch:$branchId',
      fetch: () async => (await apiClient.dio.get(
        '/organizations/$orgId/shifts',
        queryParameters: query,
      ))
          .data,
      decode: (payload) => List<Map<String, dynamic>>.from(payload as List),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> createShift(
      String orgId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '/organizations/$orgId/shifts',
      data: data,
    );
    await cache?.clearScope('organization:$orgId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateShift(
      String orgId, String shiftId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
      '/organizations/$orgId/shifts/$shiftId',
      data: data,
    );
    await cache?.clearScope('organization:$orgId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteShift(String orgId, String shiftId) async {
    await apiClient.dio.delete('/organizations/$orgId/shifts/$shiftId');
    await cache?.clearScope('organization:$orgId');
  }
}
