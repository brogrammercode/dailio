class CreateOrganizationInput {
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String timezone;
  final String currency;
  final String? logoBase64;

  CreateOrganizationInput({
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.timezone = 'Asia/Kolkata',
    this.currency = 'INR',
    this.logoBase64,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'timezone': timezone,
      'currency': currency,
      'logo_base64': logoBase64,
    };
    map.removeWhere((key, value) => value == null || value == '');
    return map;
  }
}

class CreateBranchInput {
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String country;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String timezone;
  final double? latitude;
  final double? longitude;

  CreateBranchInput({
    required this.name,
    this.address,
    this.city,
    this.state,
    this.country = 'IN',
    this.postalCode,
    this.phone,
    this.email,
    this.timezone = 'Asia/Kolkata',
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'phone': phone,
      'email': email,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
    };
    map.removeWhere((key, value) => value == null || value == '');
    return map;
  }
}


