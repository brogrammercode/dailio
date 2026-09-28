import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';

class MembersRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  MembersRepository({required this.apiClient, this.cache});

  Future<Map<String, dynamic>> listMembers(String branchId,
      {String? search,
      String? status,
      String? roleId,
      int page = 1,
      int limit = 20,
      void Function(Map<String, dynamic> freshData)? onFresh}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (roleId != null && roleId.isNotEmpty) query['role_id'] = roleId;

    final key =
        'members:$branchId:${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    if (cache == null) {
      final response = await apiClient.dio
          .get('/branches/$branchId/members', queryParameters: query);
      return response.data as Map<String, dynamic>;
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey(key),
      scope: 'branch:$branchId',
      fetch: () async => (await apiClient.dio
              .get('/branches/$branchId/members', queryParameters: query))
          .data,
      decode: (payload) => Map<String, dynamic>.from(payload as Map),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> getMember(String branchId, String memberId,
      {void Function(Map<String, dynamic> freshData)? onFresh}) async {
    if (cache == null) {
      final response =
          await apiClient.dio.get('/branches/$branchId/members/$memberId');
      return response.data as Map<String, dynamic>;
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey('member:$branchId:$memberId'),
      scope: 'branch:$branchId',
      fetch: () async =>
          (await apiClient.dio.get('/branches/$branchId/members/$memberId'))
              .data,
      decode: (payload) => Map<String, dynamic>.from(payload as Map),
      onFresh: onFresh,
    );
  }

  Future<void> suspendMember(
      String branchId, String memberId, String reason) async {
    await apiClient.dio.post(
      '/branches/$branchId/members/$memberId/suspend',
      data: {'reason': reason},
    );
    await cache?.clearScope('branch:$branchId');
  }

  Future<void> deactivateMember(
      String branchId, String memberId, String reason) async {
    await apiClient.dio.post(
      '/branches/$branchId/members/$memberId/deactivate',
      data: {'reason': reason},
    );
    await cache?.clearScope('branch:$branchId');
  }

  Future<void> createAssistedAdmission(String branchId,
      {required String firstName,
      String? lastName,
      String? email,
      String? phone}) async {
    final data = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
    };
    data.removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty));

    await apiClient.dio.post(
      '/branches/$branchId/members',
      data: data,
    );
    await cache?.clearScope('branch:$branchId');
  }

  Future<void> updateMember(
      String branchId, String memberId, Map<String, dynamic> data) async {
    await apiClient.dio.patch(
      '/branches/$branchId/members/$memberId',
      data: data,
    );
    await cache?.clearScope('branch:$branchId');
  }

  Future<Map<String, dynamic>> listOrganizationMembers(String orgId,
      {String? branchId,
      String? search,
      String? status,
      String? roleId,
      void Function(Map<String, dynamic> freshData)? onFresh}) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (roleId != null && roleId.isNotEmpty) query['role_id'] = roleId;

    if (cache == null) {
      final response = await apiClient.dio
          .get('/organizations/$orgId/members', queryParameters: query);
      return response.data as Map<String, dynamic>;
    }
    final key =
        'organization-members:$orgId:${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey(key),
      scope: branchId == null ? 'organization:$orgId' : 'branch:$branchId',
      fetch: () async => (await apiClient.dio
              .get('/organizations/$orgId/members', queryParameters: query))
          .data,
      decode: (payload) => Map<String, dynamic>.from(payload as Map),
      onFresh: onFresh,
    );
  }
}
