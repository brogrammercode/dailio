import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../models/location_discovery_model.dart';

@lazySingleton
class LocationRepository {
  final ApiClient apiClient;

  LocationRepository({required this.apiClient});

  Future<List<LocationDiscoveryModel>> discoverLocations(
      {String? query}) async {
    final response = await apiClient.dio.get(
      '/locations/discover',
      queryParameters:
          query != null && query.isNotEmpty ? {'query': query} : null,
    );
    final data = response.data['data'] as List;
    return data.map((e) => LocationDiscoveryModel.fromJson(e)).toList();
  }

  Future<void> joinLocation(String locationId, {String? message}) async {
    await apiClient.dio.post(
      '/locations/$locationId/join',
      data: {'message': message},
    );
  }
}
