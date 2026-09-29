import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';

class PayrollRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  PayrollRepository(this.apiClient, {this.cache});

  Future<List<Map<String, dynamic>>> listSalaryStructures(String orgId,
      {String? branchId,
      void Function(List<Map<String, dynamic>> freshStructures)?
          onFresh}) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;
    if (cache == null) {
      final response = await apiClient.dio.get(
        '/organizations/$orgId/salary-structures',
        queryParameters: query,
      );
      return (response.data['data'] as List).cast<Map<String, dynamic>>();
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('salary-structures:$orgId:${branchId ?? 'all'}'),
      scope: branchId == null ? 'organization:$orgId' : 'branch:$branchId',
      fetch: () async => (await apiClient.dio.get(
        '/organizations/$orgId/salary-structures',
        queryParameters: query,
      ))
          .data,
      decode: (payload) =>
          ((payload as Map)['data'] as List).cast<Map<String, dynamic>>(),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> createSalaryStructure(
      String orgId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '/organizations/$orgId/salary-structures',
      data: data,
    );
    await cache?.clearScope('organization:$orgId');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSalaryStructure(
      String orgId, String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
      '/organizations/$orgId/salary-structures/$id',
      data: data,
    );
    await cache?.clearScope('organization:$orgId');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> deleteSalaryStructure(String orgId, String id) async {
    await apiClient.dio.delete('/organizations/$orgId/salary-structures/$id');
    await cache?.clearScope('organization:$orgId');
  }
}
