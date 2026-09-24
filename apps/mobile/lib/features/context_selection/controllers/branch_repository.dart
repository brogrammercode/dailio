import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../models/branch_discovery_model.dart';

@lazySingleton
class BranchRepository {
  final ApiClient apiClient;

  BranchRepository({required this.apiClient});

  Future<List<BranchDiscoveryModel>> discoverBranches({String? query}) async {
    final response = await apiClient.dio.get(
      '/branches/discover',
      queryParameters:
          query != null && query.isNotEmpty ? {'query': query} : null,
    );
    final data = response.data['data'] as List;
    return data.map((e) => BranchDiscoveryModel.fromJson(e)).toList();
  }

  /// Fetch all branches belonging to a specific org (used after QR scan).
  Future<List<BranchDiscoveryModel>> discoverBranchesByOrg(String orgId) async {
    final response = await apiClient.dio.get(
      '/branches/discover',
      queryParameters: {'org_id': orgId},
    );
    final data = response.data['data'] as List;
    return data.map((e) => BranchDiscoveryModel.fromJson(e)).toList();
  }

  Future<void> joinBranch(String branchId, {String? message}) async {
    final data = <String, dynamic>{'message': message};
    data.removeWhere((key, value) => value == null || value == '');

    await apiClient.dio.post(
      '/branches/$branchId/join',
      data: data,
    );
  }
}
