import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';
import '../models/join_request_model.dart';

@lazySingleton
class AdmissionRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  AdmissionRepository({required this.apiClient, this.cache});

  Future<List<JoinRequestModel>> getPendingRequests(String branchId,
      {void Function(List<JoinRequestModel> freshRequests)? onFresh}) async {
    if (cache == null) {
      final response =
          await apiClient.dio.get('/branches/$branchId/join-requests');
      return (response.data as List)
          .map((e) => JoinRequestModel.fromJson(e))
          .toList();
    }
    return cache!.load<List<JoinRequestModel>>(
      key: cache!.scopedKey('join-requests:$branchId'),
      scope: 'branch:$branchId',
      fetch: () async =>
          (await apiClient.dio.get('/branches/$branchId/join-requests')).data,
      decode: (payload) => (payload as List)
          .map((e) => JoinRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      onFresh: onFresh,
    );
  }

  Future<void> approveRequest(String branchId, String requestId,
      {String? reason}) async {
    final data = <String, dynamic>{'reason': reason};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join-requests/$requestId/approve',
      data: data,
    );
    await cache?.clearScope('branch:$branchId');
  }

  Future<void> rejectRequest(String branchId, String requestId,
      {String? reason}) async {
    final data = <String, dynamic>{'reason': reason};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join-requests/$requestId/reject',
      data: data,
    );
    await cache?.clearScope('branch:$branchId');
  }
}
