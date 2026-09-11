import '../../../core/network/api_client.dart';

class MembersRepository {
  final ApiClient apiClient;

  MembersRepository({required this.apiClient});

  Future<Map<String, dynamic>> listMembers(String branchId, {String? search, String? status, String? roleId, int page = 1}) async {
    final query = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (roleId != null && roleId.isNotEmpty) query['role_id'] = roleId;

    final response = await apiClient.dio.get(
      '/branches/$branchId/members',
      queryParameters: query,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMember(String branchId, String memberId) async {
    final response = await apiClient.dio.get('/branches/$branchId/members/$memberId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> suspendMember(String branchId, String memberId, String reason) async {
    await apiClient.dio.post(
      '/branches/$branchId/members/$memberId/suspend',
      data: {'reason': reason},
    );
  }

  Future<void> deactivateMember(String branchId, String memberId, String reason) async {
    await apiClient.dio.post(
      '/branches/$branchId/members/$memberId/deactivate',
      data: {'reason': reason},
    );
  }

  Future<void> createAssistedAdmission(String branchId, { required String firstName, String? lastName, String? email, String? phone }) async {
    final data = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
    };
    data.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    await apiClient.dio.post(
      '/branches/$branchId/members',
      data: data,
    );
  }
  Future<void> updateMember(String branchId, String memberId, Map<String, dynamic> data) async {
    await apiClient.dio.patch(
      '/branches/$branchId/members/$memberId',
      data: data,
    );
  }
}
