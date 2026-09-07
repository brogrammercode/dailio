class CreateOrganizationInput {
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String timezone;
  final String currency;

  CreateOrganizationInput({
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.timezone = 'Asia/Kolkata',
    this.currency = 'INR',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'timezone': timezone,
        'currency': currency,
      };
}

class CreateLocationInput {
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String country;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String timezone;

  CreateLocationInput({
    required this.name,
    this.address,
    this.city,
    this.state,
    this.country = 'IN',
    this.postalCode,
    this.phone,
    this.email,
    this.timezone = 'Asia/Kolkata',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'postal_code': postalCode,
        'phone': phone,
        'email': email,
        'timezone': timezone,
      };
}
