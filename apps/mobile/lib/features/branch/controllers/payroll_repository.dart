import '../../../core/network/api_client.dart';

class PayrollRepository {
  final ApiClient apiClient;
  PayrollRepository(this.apiClient);

  Future<List<Map<String, dynamic>>> listSalaryStructures(String orgId, {String? branchId}) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;
    final response = await apiClient.dio.get('/organizations//salary-structures', queryParameters: query);
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createSalaryStructure(String orgId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/organizations//salary-structures', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSalaryStructure(String orgId, String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch('/organizations//salary-structures/', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> deleteSalaryStructure(String orgId, String id) async {
    await apiClient.dio.delete('/organizations//salary-structures/');
  }
}


