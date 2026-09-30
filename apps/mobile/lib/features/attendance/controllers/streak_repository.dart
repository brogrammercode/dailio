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
    Map<String, dynamic> decode(dynamic payload) {
      final envelope = payload is Map
          ? Map<String, dynamic>.from(payload)
          : const <String, dynamic>{};
      final data = envelope['data'] is Map ? envelope['data'] as Map : envelope;
      final result = Map<String, dynamic>.from(data);
      return {
        ...result,
        'current_streak': (result['current_streak'] as num?)?.toInt() ?? 0,
        'best_streak': (result['best_streak'] as num?)?.toInt() ?? 0,
      };
    }

    final fallback = <String, dynamic>{
      'current_streak': 0,
      'best_streak': 0,
      'last_attendance_date': null,
    };

    if (cache == null) {
      try {
        return decode(await fetch());
      } catch (_) {
        return fallback;
      }
    }

    final scopedKey = cache!.scopedKey(key);
    try {
      return await cache!.load<Map<String, dynamic>>(
        key: scopedKey,
        scope: 'branch:${branchIdFromPath(path)}',
        fetch: fetch,
        decode: decode,
        onFresh: onFresh,
      );
    } catch (_) {
      // A malformed/old cache record or a temporary API failure should not
      // replace the Settings page with an error state. Use the last valid
      // cached streak when available, otherwise show the honest zero state.
      try {
        final cached = await cache!.read(scopedKey);
        if (cached != null) return decode(cached.payload);
      } catch (_) {}
      return fallback;
    }
  }

  String branchIdFromPath(String path) {
    final parts = path.split('/');
    return parts.length > 1 ? parts[1] : path;
  }
}
