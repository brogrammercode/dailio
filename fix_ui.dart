import 'dart:io';

void main() {
  var file = File('apps/mobile/lib/features/organization/pages/create_organization_page.dart');
  var content = file.readAsStringSync();

  // 1. Update variables
  content = content.replaceFirst(
    "String _orgIndustry = 'Fitness / Gym & Athletics';",
    "String _orgType = 'GYM';\n  String _orgAddress = '';"
  );

  // 2. Update _nextStep
  var oldNextStep = '''
      final input = CreateOrganizationInput(
        name: _orgName,
        email: _orgEmail.isEmpty ? null : _orgEmail,
        phone: _orgPhone.isEmpty ? null : _orgPhone,
        timezone: _orgTimezone,
        currency: _orgCurrency,
        logoBase64: _logoBase64,
      );
''';
  var newNextStep = '''
      final input = CreateOrganizationInput(
        name: _orgName,
        type: _orgType,
        address: _orgAddress.isEmpty ? null : _orgAddress,
        email: _orgEmail.isEmpty ? null : _orgEmail,
        phone: _orgPhone.isEmpty ? null : _orgPhone,
        timezone: _orgTimezone,
        currency: _orgCurrency,
        logoBase64: _logoBase64,
      );
''';
  content = content.replaceFirst(oldNextStep, newNextStep);

  // 3. Update Industry Dropdown to Type Dropdown
  var oldDropdown = '''
        _fieldLabel('Primary Category / Industry'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgIndustry, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: [
            'Fitness / Gym & Athletics',
            'Corporate',
            'Education',
            'Healthcare',
            'Other'
          ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (v) => setState(() => _orgIndustry = v!),
          onSaved: (v) => _orgIndustry = v ?? 'Fitness / Gym & Athletics',
        ),
''';
  var newDropdown = '''
        _fieldLabel('Primary Category / Industry'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgType, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(value: 'GYM', child: Text('Fitness / Gym & Athletics')),
            DropdownMenuItem(value: 'COACHING', child: Text('Coaching & Training')),
            DropdownMenuItem(value: 'CLINIC', child: Text('Health & Clinic')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other Business Type')),
          ],
          onChanged: (v) => setState(() => _orgType = v!),
          onSaved: (v) => _orgType = v ?? 'GYM',
        ),
''';
  content = content.replaceFirst(oldDropdown, newDropdown);

  // 4. Insert Address Field after Phone
  var oldPhoneField = '''
        TextFormField(
          initialValue: _orgPhone,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.phone_outlined, size: 18),
            hintText: '+91 98765 43210',
          ),
          keyboardType: TextInputType.phone,
          onSaved: (v) => _orgPhone = v ?? '',
        ),
        const SizedBox(height: 40),
''';
  var newPhoneAndAddressField = '''
        TextFormField(
          initialValue: _orgPhone,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.phone_outlined, size: 18),
            hintText: '+91 98765 43210',
          ),
          keyboardType: TextInputType.phone,
          onSaved: (v) => _orgPhone = v ?? '',
        ),
        const SizedBox(height: 20),

        _fieldLabel('Registered HQ Address'),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgAddress,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_city_outlined, size: 18),
            hintText: '123 Main Street, Suite 400',
          ),
          onSaved: (v) => _orgAddress = v ?? '',
        ),
        const SizedBox(height: 40),
''';
  content = content.replaceFirst(oldPhoneField, newPhoneAndAddressField);

  file.writeAsStringSync(content);
}
