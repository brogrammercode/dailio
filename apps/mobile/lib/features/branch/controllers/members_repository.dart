import '../../../core/network/api_client.dart';

class MembersRepository {
  final ApiClient apiClient;

  MembersRepository({required this.apiClient});

  Future<Map<String, dynamic>> listMembers(String locationId, {String? search, String? status, int page = 1}) async {
    final query = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await apiClient.dio.get(
      '/locations/$locationId/members',
      queryParameters: query,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMember(String locationId, String membershipId) async {
    final response = await apiClient.dio.get('/locations/$locationId/members/$membershipId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> suspendMember(String locationId, String membershipId, String reason) async {
    await apiClient.dio.post(
      '/locations/$locationId/members/$membershipId/suspend',
      data: {'reason': reason},
    );
  }

  Future<void> deactivateMember(String locationId, String membershipId, String reason) async {
    await apiClient.dio.post(
      '/locations/$locationId/members/$membershipId/deactivate',
      data: {'reason': reason},
    );
  }

  Future<void> createAssistedAdmission(String locationId, { required String firstName, String? lastName, String? email, String? phone }) async {
    final data = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
    };
    data.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    await apiClient.dio.post(
      '/locations/$locationId/members',
      data: data,
    );
  }
}
