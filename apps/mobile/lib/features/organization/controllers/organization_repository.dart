import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';
import '../models/create_organization_models.dart';

class OrganizationRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  OrganizationRepository({required this.apiClient, this.cache});

  Future<Map<String, dynamic>> createOrganization(
    CreateOrganizationInput organization,
    CreateBranchInput branch,
  ) async {
    final response = await apiClient.dio.post(
      '/organizations',
      data: {
        'organization': organization.toJson(),
        'location': branch.toJson(),
      },
    );
    await cache?.clearScope('user');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyOrganizations() async {
    return cache == null
        ? _fetchOrganizations()
        : cache!.load<List<Map<String, dynamic>>>(
            key: cache!.scopedKey('organizations'),
            scope: 'user',
            fetch: () async => (await apiClient.dio.get('/organizations')).data,
            decode: (payload) => List<Map<String, dynamic>>.from(
              (payload as Map)['organizations'] as List,
            ),
          );
  }

  Future<List<Map<String, dynamic>>> _fetchOrganizations() async {
    final response = await apiClient.dio.get('/organizations');
    return List<Map<String, dynamic>>.from(response.data['organizations']);
  }

  Future<Map<String, dynamic>> getOrganizationById(String orgId,
      {void Function(Map<String, dynamic> freshData)? onFresh}) async {
    Future<Map<String, dynamic>> fetch(dynamic payload) => Future.value(
          Map<String, dynamic>.from((payload as Map)['organization'] as Map),
        );
    if (cache == null) {
      final response = await apiClient.dio.get('/organizations/$orgId');
      return fetch(response.data);
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey('organization:$orgId'),
      scope: 'organization:$orgId',
      fetch: () async =>
          (await apiClient.dio.get('/organizations/$orgId')).data,
      decode: (payload) =>
          Map<String, dynamic>.from(((payload as Map)['organization'] as Map)),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> updateOrganization(
      String orgId, Map<String, dynamic> data) async {
    final response =
        await apiClient.dio.patch('/organizations/$orgId', data: data);
    await cache?.clearScope('organization:$orgId');
    await cache?.clearScope('user');
    return response.data['organization'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRoles(String orgId,
      {String? branchId,
      void Function(List<Map<String, dynamic>> freshRoles)? onFresh}) async {
    final query = <String, dynamic>{'organization_id': orgId};
    if (branchId != null) query['branch_id'] = branchId;
    final key = 'roles:$orgId:${branchId ?? 'all'}';
    if (cache == null) {
      final response =
          await apiClient.dio.get('/roles', queryParameters: query);
      return List<Map<String, dynamic>>.from(response.data['roles']);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey(key),
      scope: branchId == null ? 'organization:$orgId' : 'branch:$branchId',
      fetch: () async =>
          (await apiClient.dio.get('/roles', queryParameters: query)).data,
      decode: (payload) =>
          List<Map<String, dynamic>>.from(((payload as Map)['roles'] as List)),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> createRole(
      String orgId, String name, List<String> permissions,
      {String? branchId}) async {
    final payload = <String, dynamic>{
      'organization_id': orgId,
      'name': name,
      'permissions': permissions,
    };
    if (branchId != null && branchId != 'none') payload['branch_id'] = branchId;

    final response = await apiClient.dio.post('/roles', data: payload);
    await cache?.clearScope('organization:$orgId');
    if (branchId != null && branchId != 'none') {
      await cache?.clearScope('branch:$branchId');
    }
    return response.data['role'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRole(String roleId,
      {String? name,
      List<String>? permissions,
      String? branchId,
      bool clearBranch = false}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (permissions != null) data['permissions'] = permissions;
    if (branchId != null) {
      data['branch_id'] = branchId;
    } else if (clearBranch) {
      data['branch_id'] = null;
    }
    final response = await apiClient.dio.patch('/roles/$roleId', data: data);
    // The update route accepts only a role id, so the complete affected
    // organization/branch scope is not known until the response arrives.
    // Clearing the user's read-model cache keeps all role/context views safe.
    await cache?.clearAll();
    return response.data['role'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBranch(
      String orgId, CreateBranchInput branch) async {
    final response = await apiClient.dio
        .post('/organizations/$orgId/branches', data: branch.toJson());
    await cache?.clearScope('organization:$orgId');
    await cache?.clearScope('user');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOrganizationBranches(String orgId,
      {void Function(List<Map<String, dynamic>> freshBranches)?
          onFresh}) async {
    if (cache == null) {
      final response =
          await apiClient.dio.get('/organizations/$orgId/branches');
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('branches:$orgId'),
      scope: 'organization:$orgId',
      fetch: () async =>
          (await apiClient.dio.get('/organizations/$orgId/branches')).data,
      decode: (payload) =>
          List<Map<String, dynamic>>.from(((payload as Map)['data'] as List)),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> updateBranch(
      String orgId, String branchId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .patch('/organizations/$orgId/branches/$branchId', data: data);
    await cache?.clearScope('organization:$orgId');
    await cache?.clearScope('branch:$branchId');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBranchById(String orgId, String branchId,
      {void Function(Map<String, dynamic> freshBranch)? onFresh}) async {
    if (cache == null) {
      final response =
          await apiClient.dio.get('/organizations/$orgId/branches/$branchId');
      return response.data['data'] as Map<String, dynamic>;
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey('branch:$branchId'),
      scope: 'branch:$branchId',
      fetch: () async =>
          (await apiClient.dio.get('/organizations/$orgId/branches/$branchId'))
              .data,
      decode: (payload) =>
          Map<String, dynamic>.from((payload as Map)['data'] as Map),
      onFresh: onFresh,
    );
  }

  Future<List<Map<String, dynamic>>> getOrganizationPlans(String orgId,
      {String? branchId,
      void Function(List<Map<String, dynamic>> freshPlans)? onFresh}) async {
    final query = {if (branchId != null) 'branch_id': branchId};
    if (cache == null) {
      final response = await apiClient.dio
          .get('/organizations/$orgId/plans', queryParameters: query);
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return cache!.load<List<Map<String, dynamic>>>(
      key: cache!.scopedKey('plans:$orgId:${branchId ?? 'all'}'),
      scope: branchId == null ? 'organization:$orgId' : 'branch:$branchId',
      fetch: () async => (await apiClient.dio
              .get('/organizations/$orgId/plans', queryParameters: query))
          .data,
      decode: (payload) =>
          List<Map<String, dynamic>>.from(((payload as Map)['data'] as List)),
      onFresh: onFresh,
    );
  }

  Future<Map<String, dynamic>> createPlan(
      String orgId, Map<String, dynamic> data) async {
    final response =
        await apiClient.dio.post('/organizations/$orgId/plans', data: data);
    final plan = Map<String, dynamic>.from(response.data['data'] as Map);
    await cache?.clearScope('organization:$orgId');
    final branchId = plan['branch_id']?.toString();
    if (branchId != null && branchId.isNotEmpty) {
      await cache?.clearScope('branch:$branchId');
    }
    return plan;
  }

  Future<Map<String, dynamic>> updatePlan(
      String orgId, String planId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .patch('/organizations/$orgId/plans/$planId', data: data);
    final plan = Map<String, dynamic>.from(response.data['data'] as Map);
    await cache?.clearScope('organization:$orgId');
    final branchId = plan['branch_id']?.toString();
    if (branchId != null && branchId.isNotEmpty) {
      await cache?.clearScope('branch:$branchId');
    }
    return plan;
  }
}
