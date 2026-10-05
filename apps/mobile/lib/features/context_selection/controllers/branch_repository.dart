import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';
import '../models/branch_discovery_model.dart';

@lazySingleton
class BranchRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  BranchRepository({required this.apiClient, this.cache});

  Future<List<BranchDiscoveryModel>> discoverBranches({String? query}) async {
    final queryParams =
        query != null && query.isNotEmpty ? {'query': query} : null;
    if (cache == null) {
      final response = await apiClient.dio
          .get('/branches/discover', queryParameters: queryParams);
      return (response.data['data'] as List)
          .map((e) => BranchDiscoveryModel.fromJson(e))
          .toList();
    }
    return cache!.load<List<BranchDiscoveryModel>>(
      key: cache!.scopedKey('branch-discovery:${query ?? ''}'),
      scope: 'user',
      fetch: () async => (await apiClient.dio
              .get('/branches/discover', queryParameters: queryParams))
          .data,
      decode: (payload) => ((payload as Map)['data'] as List)
          .map((e) => BranchDiscoveryModel.fromJson(e))
          .toList(),
    );
  }

  /// Fetch all branches belonging to a specific org (used after QR scan).
  Future<List<BranchDiscoveryModel>> discoverBranchesByOrg(String orgId) async {
    if (cache == null) {
      final response = await apiClient.dio
          .get('/branches/discover', queryParameters: {'org_id': orgId});
      return (response.data['data'] as List)
          .map((e) => BranchDiscoveryModel.fromJson(e))
          .toList();
    }
    return cache!.load<List<BranchDiscoveryModel>>(
      key: cache!.scopedKey('branch-discovery-org:$orgId'),
      scope: 'user',
      fetch: () async => (await apiClient.dio
              .get('/branches/discover', queryParameters: {'org_id': orgId}))
          .data,
      decode: (payload) => ((payload as Map)['data'] as List)
          .map((e) => BranchDiscoveryModel.fromJson(e))
          .toList(),
    );
  }

  Future<void> joinBranch(String branchId, {String? message}) async {
    final data = <String, dynamic>{'message': message};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join',
      data: data,
    );
    await cache?.clearScope('user');
  }

  Future<Map<String, dynamic>> resolveInvite(String token) async {
    final response = await apiClient.dio.get('/invites/$token');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> submitInviteJoinRequest(
    String token, {
    String? message,
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/join-invites/$token/requests',
      data: {
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim()
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    await cache?.clearScope('user');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> fastJoinFromInvite(
    String token, {
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/join-invites/$token/fast-join',
      data: const <String, dynamic>{},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    await cache?.clearScope('user');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> serveMealFromInvite(
    String token,
    String mealSlotId, {
    String? branchId,
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/meal-attendance-invites/$token/serve',
      data: {'meal_slot_id': mealSlotId},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    if (branchId != null) await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createBranchInvite(String branchId) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/join-invites',
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createPlanInvite(
      String branchId, String planId) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/plans/$planId/purchase-invites',
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<void> revokeInvite(String branchId, String inviteId,
      {String? planId}) async {
    final path = planId == null
        ? '/branches/$branchId/join-invites/$inviteId/revoke'
        : '/branches/$branchId/plans/$planId/purchase-invites/$inviteId/revoke';
    await apiClient.dio.post(path);
  }

  Future<Map<String, dynamic>> createSubscriptionDraft(
    String token,
    String startDate, {
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/purchase-invites/$token/subscription-drafts',
      data: {'start_date': startDate},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createDirectSubscriptionDraft(
    String branchId,
    String planId,
    String startDate, {
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/plans/$planId/subscription-drafts',
      data: {'start_date': startDate},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}
