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
}
