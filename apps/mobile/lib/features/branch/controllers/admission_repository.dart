import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../models/join_request_model.dart';

@lazySingleton
class AdmissionRepository {
  final ApiClient apiClient;

  AdmissionRepository({required this.apiClient});

  Future<List<JoinRequestModel>> getPendingRequests(String locationId) async {
    final response = await apiClient.dio.get(
      '/locations/$locationId/join-requests',
    );
    final data = response.data as List;
    return data.map((e) => JoinRequestModel.fromJson(e)).toList();
  }

  Future<void> approveRequest(String locationId, String requestId,
      {String? reason}) async {
    final data = <String, dynamic>{'reason': reason};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/locations/$locationId/join-requests/$requestId/approve',
      data: data,
    );
  }

  Future<void> rejectRequest(String locationId, String requestId,
      {String? reason}) async {
    final data = <String, dynamic>{'reason': reason};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/locations/$locationId/join-requests/$requestId/reject',
      data: data,
    );
  }
}
