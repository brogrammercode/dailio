import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';

class MealsRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  MealsRepository(this.apiClient, {this.cache});

  List<Map<String, dynamic>> _rows(dynamic body) =>
      ((body as Map)['data'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<List<Map<String, dynamic>>> slots(String branchId) async {
    if (cache == null) {
      return _rows(
          (await apiClient.dio.get('/branches/$branchId/meal-slots')).data);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('meals:slots:$branchId'),
      scope: 'branch:$branchId',
      fetch: () async =>
          (await apiClient.dio.get('/branches/$branchId/meal-slots')).data,
      decode: _rows,
    );
  }

  Future<Map<String, dynamic>> servings(String branchId,
          {int page = 1,
          String? memberId,
          String? from,
          String? to,
          int limit = 30}) async =>
      _loadMap(
        key: _servingsKey(branchId, page, memberId, from, to, limit),
        scope: 'branch:$branchId',
        path: '/branches/$branchId/meal-servings',
        query: {
          'page': page,
          'limit': limit,
          if (memberId != null) 'member_id': memberId,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );

  Future<Map<String, dynamic>> summary(String branchId,
      {String? memberId}) async {
    final body = await _loadMap(
      key: 'meals:summary:$branchId:${memberId ?? 'self'}',
      scope: 'branch:$branchId',
      path: '/branches/$branchId/meal-servings/summary',
      query: {if (memberId != null) 'member_id': memberId},
    );
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> members(
          String branchId, String query) async =>
      _rows((await apiClient.dio.get('/branches/$branchId/meal-members',
              queryParameters: {'query': query}))
          .data);

  Future<Map<String, dynamic>> eligibility(
          String branchId, String slotId, String memberId) async =>
      Map<String, dynamic>.from((await apiClient.dio.get(
              '/branches/$branchId/meal-slots/$slotId/eligibility',
              queryParameters: {'member_id': memberId}))
          .data['data'] as Map);

  Future<void> serve(String branchId, String memberId, String slotId) async {
    await apiClient.dio.post('/branches/$branchId/meal-servings',
        data: {'member_id': memberId, 'meal_slot_id': slotId},
        options: Options(headers: {
          'Idempotency-Key':
              'mobile-meal-${DateTime.now().toUtc().microsecondsSinceEpoch}'
        }));
    await cache?.clearScope('branch:$branchId');
  }

  Future<void> voidServing(
      String branchId, String servingId, String reason) async {
    await apiClient.dio.post(
        '/branches/$branchId/meal-servings/$servingId/void',
        data: {'reason': reason});
    await cache?.clearScope('branch:$branchId');
  }

  Future<void> saveSlot(String branchId, Map<String, dynamic> data,
      {String? id}) async {
    if (id == null) {
      await apiClient.dio.post('/branches/$branchId/meal-slots', data: data);
    } else {
      await apiClient.dio.put('/branches/$branchId/meal-slots/$id', data: data);
    }
    await cache?.clearScope('branch:$branchId');
  }

  Future<List<Map<String, dynamic>>> plans(String organizationId) async {
    if (cache == null) {
      return _rows(
          (await apiClient.dio.get('/organizations/$organizationId/plans'))
              .data);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('meals:plans:$organizationId'),
      scope: 'organization:$organizationId',
      fetch: () async =>
          (await apiClient.dio.get('/organizations/$organizationId/plans'))
              .data,
      decode: _rows,
    );
  }

  Future<List<Map<String, dynamic>>> entitlements(
          String branchId, String planId) async =>
      _loadRows(
        key: 'meals:entitlements:$branchId:$planId',
        scope: 'branch:$branchId',
        path: '/branches/$branchId/plans/$planId/meal-entitlements',
      );

  Future<void> setEntitlement(String branchId, String planId, String slotId,
      int limit, bool active) async {
    await apiClient.dio
        .put('/branches/$branchId/plans/$planId/meal-entitlements', data: {
      'meal_slot_id': slotId,
      'max_servings_per_day': limit,
      'is_active': active
    });
    await cache?.clearScope('branch:$branchId');
  }

  Future<Map<String, dynamic>> createMealInvite(String branchId) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/meal-attendance-invites',
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> _loadRows({
    required String key,
    required String scope,
    required String path,
    Map<String, dynamic>? query,
  }) async {
    if (cache == null) {
      return _rows(
          (await apiClient.dio.get(path, queryParameters: query)).data);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey(key),
      scope: scope,
      fetch: () async =>
          (await apiClient.dio.get(path, queryParameters: query)).data,
      decode: _rows,
    );
  }

  Future<Map<String, dynamic>> _loadMap({
    required String key,
    required String scope,
    required String path,
    Map<String, dynamic>? query,
  }) async {
    if (cache == null) {
      return Map<String, dynamic>.from(
          (await apiClient.dio.get(path, queryParameters: query)).data as Map);
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey(key),
      scope: scope,
      fetch: () async =>
          (await apiClient.dio.get(path, queryParameters: query)).data,
      decode: (payload) => Map<String, dynamic>.from(payload as Map),
    );
  }

  String _servingsKey(String branchId, int page, String? memberId, String? from,
          String? to, int limit) =>
      'meals:servings:$branchId:$page:${memberId ?? ''}:${from ?? ''}:${to ?? ''}:$limit';
}
