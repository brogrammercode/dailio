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

  Future<Map<String, dynamic>> updateOrganization(String orgId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch('/organizations/$orgId', data: data);
    return response.data['organization'] as Map<String, dynamic>;
  }
}
