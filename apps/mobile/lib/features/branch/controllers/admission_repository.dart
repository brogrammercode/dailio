import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../models/join_request_model.dart';

@lazySingleton
class AdmissionRepository {
  final ApiClient apiClient;

  AdmissionRepository({required this.apiClient});

  Future<List<JoinRequestModel>> getPendingRequests(String branchId) async {
    final response = await apiClient.dio.get(
      '/branches/$branchId/join-requests',
    );
    final data = response.data as List;
    return data.map((e) => JoinRequestModel.fromJson(e)).toList();
  }

  Future<void> approveRequest(String branchId, String requestId,
      {String? reason}) async {
    final data = <String, dynamic>{'reason': reason};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join-requests/$requestId/approve',
      data: data,
    );
  }

  Future<void> rejectRequest(String branchId, String requestId,
      {String? reason}) async {
    final data = <String, dynamic>{'reason': reason};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join-requests/$requestId/reject',
      data: data,
    );
  }
}

