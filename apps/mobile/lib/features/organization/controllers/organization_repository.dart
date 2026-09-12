import '../../../core/network/api_client.dart';
import '../models/create_organization_models.dart';

class OrganizationRepository {
  final ApiClient apiClient;

  OrganizationRepository({required this.apiClient});

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
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyOrganizations() async {
    final response = await apiClient.dio.get('/organizations');
    return List<Map<String, dynamic>>.from(response.data['organizations']);
  }

  Future<Map<String, dynamic>> getOrganizationById(String orgId) async {
    final response = await apiClient.dio.get('/organizations/$orgId');
    return response.data['organization'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOrganization(
      String orgId, Map<String, dynamic> data) async {
    final response =
        await apiClient.dio.patch('/organizations/$orgId', data: data);
    return response.data['organization'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRoles(String orgId, {String? branchId}) async {
    final query = <String, dynamic>{'organization_id': orgId};
    if (branchId != null) query['branch_id'] = branchId;
    final response = await apiClient.dio.get('/roles', queryParameters: query);
    return List<Map<String, dynamic>>.from(response.data['roles']);
  }

  Future<Map<String, dynamic>> createRole(
      String orgId, String name, List<String> permissions, {String? branchId}) async {
    final payload = <String, dynamic>{
      'organization_id': orgId,
      'name': name,
      'permissions': permissions,
    };
    if (branchId != null && branchId != 'none') payload['branch_id'] = branchId;
    
    final response = await apiClient.dio.post('/roles', data: payload);
    return response.data['role'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRole(String roleId, {String? name, List<String>? permissions, String? branchId, bool clearBranch = false}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (permissions != null) data['permissions'] = permissions;
    if (branchId != null) {
      data['branch_id'] = branchId;
    } else if (clearBranch) {
      data['branch_id'] = null;
    }
    final response = await apiClient.dio.patch('/roles/$roleId', data: data);
    return response.data['role'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBranch(
      String orgId, CreateBranchInput branch) async {
    final response = await apiClient.dio
        .post('/organizations/$orgId/branches', data: branch.toJson());
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOrganizationBranches(
      String orgId) async {
    final response = await apiClient.dio.get('/organizations/$orgId/branches');
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> updateBranch(
      String orgId, String branchId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .patch('/organizations/$orgId/branches/$branchId', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBranchById(
      String orgId, String branchId) async {
    final response =
        await apiClient.dio.get('/organizations/$orgId/branches/$branchId');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOrganizationPlans(String orgId) async {
    final response = await apiClient.dio.get('/organizations/$orgId/plans');
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> createPlan(
      String orgId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .post('/organizations/$orgId/plans', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePlan(
      String orgId, String planId, Map<String, dynamic> data) async {
    final response = await apiClient.dio
        .patch('/organizations/$orgId/plans/$planId', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

}




