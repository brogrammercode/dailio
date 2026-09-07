class LocationDiscoveryModel {
  final String id;
  final String organizationId;
  final String name;
  final String? address;
  final OrganizationDiscoveryModel organization;

  LocationDiscoveryModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.address,
    required this.organization,
  });

  factory LocationDiscoveryModel.fromJson(Map<String, dynamic> json) {
    return LocationDiscoveryModel(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      address: json['address'],
      organization: OrganizationDiscoveryModel.fromJson(json['organization']),
    );
  }
}

class OrganizationDiscoveryModel {
  final String id;
  final String name;
  final String? logoUrl;

  OrganizationDiscoveryModel({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  factory OrganizationDiscoveryModel.fromJson(Map<String, dynamic> json) {
    return OrganizationDiscoveryModel(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'],
    );
  }
}
