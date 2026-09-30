import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';

class StreakRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  StreakRepository({required this.apiClient, this.cache});

  Future<Map<String, dynamic>> getMyStreak(
    String branchId, {
    void Function(Map<String, dynamic> fresh)? onFresh,
  }) =>
      _get('branches/$branchId/attendance/streak', 'streak:me:$branchId',
          onFresh: onFresh);

  Future<Map<String, dynamic>> getMemberStreak(
    String branchId,
    String memberId, {
    void Function(Map<String, dynamic> fresh)? onFresh,
  }) =>
      _get('branches/$branchId/attendance/streak/$memberId',
          'streak:$memberId:$branchId',
          onFresh: onFresh);

  Future<Map<String, dynamic>> _get(
    String path,
    String key, {
    void Function(Map<String, dynamic> fresh)? onFresh,
  }) async {
    Future<dynamic> fetch() async => (await apiClient.dio.get('/$path')).data;
    if (cache == null) {
      final response = await fetch();
      return Map<String, dynamic>.from((response as Map)['data'] as Map);
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey(key),
      scope: 'branch:$path',
      fetch: fetch,
      decode: (payload) =>
          Map<String, dynamic>.from((payload as Map)['data'] as Map),
      onFresh: onFresh,
    );
  }
}
