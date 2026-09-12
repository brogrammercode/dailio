import '../../../core/network/api_client.dart';

class ShiftRepository {
  final ApiClient apiClient;

  ShiftRepository(this.apiClient);

  Future<List<Map<String, dynamic>>> listShifts(String orgId, {String? branchId}) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;
    
    final response = await apiClient.dio.get('/organizations/$orgId/shifts', queryParameters: query);
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createShift(String orgId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/organizations/$orgId/shifts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateShift(String orgId, String shiftId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch('/organizations/$orgId/shifts/$shiftId', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteShift(String orgId, String shiftId) async {
    await apiClient.dio.delete('/organizations/$orgId/shifts/$shiftId');
  }
}
