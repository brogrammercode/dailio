import 'dart:io';

void main() {
  var file = File('apps/mobile/lib/features/organization/pages/create_organization_page.dart');
  var content = file.readAsStringSync();
  
  var regex = RegExp(r"final input = CreateOrganizationInput\([^)]+\);", dotAll: true);
  
  var newCall = '''final input = CreateOrganizationInput(
          name: _orgName,
          type: _orgType,
          address: _orgAddress.isEmpty ? null : _orgAddress,
          email: _orgEmail.isEmpty ? null : _orgEmail,
          phone: _orgPhone.isEmpty ? null : _orgPhone,
          timezone: _orgTimezone,
          currency: _orgCurrency,
          logoBase64: _logoBase64,
        );''';

  content = content.replaceFirst(regex, newCall);
  file.writeAsStringSync(content);
}
