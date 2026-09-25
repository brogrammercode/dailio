import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/branch_discovery_model.dart';

@lazySingleton
class BranchRepository {
  final ApiClient apiClient;

  BranchRepository({required this.apiClient});

  Future<List<BranchDiscoveryModel>> discoverBranches({String? query}) async {
    final response = await apiClient.dio.get(
      '/branches/discover',
      queryParameters:
          query != null && query.isNotEmpty ? {'query': query} : null,
    );
    final data = response.data['data'] as List;
    return data.map((e) => BranchDiscoveryModel.fromJson(e)).toList();
  }

  /// Fetch all branches belonging to a specific org (used after QR scan).
  Future<List<BranchDiscoveryModel>> discoverBranchesByOrg(String orgId) async {
    final response = await apiClient.dio.get(
      '/branches/discover',
      queryParameters: {'org_id': orgId},
    );
    final data = response.data['data'] as List;
    return data.map((e) => BranchDiscoveryModel.fromJson(e)).toList();
  }

  Future<void> joinBranch(String branchId, {String? message}) async {
    final data = <String, dynamic>{'message': message};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join',
      data: data,
    );
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
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createBranchInvite(String branchId,
      {int expiresInHours = 24}) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/join-invites',
      data: {'expires_in_hours': expiresInHours},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createPlanInvite(String branchId, String planId,
      {int expiresInHours = 24}) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/plans/$planId/purchase-invites',
      data: {'expires_in_hours': expiresInHours},
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
}
