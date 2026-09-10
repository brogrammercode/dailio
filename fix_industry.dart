import 'dart:io';

void main() {
  var file = File('apps/mobile/lib/features/organization/pages/create_organization_page.dart');
  var content = file.readAsStringSync();

  // We know the exact _orgType and _orgAddress definitions were added.
  // We need to replace the DropdownButtonFormField for _orgIndustry.
  
  var regex = RegExp(r"DropdownButtonFormField<String>\(\s*value:\s*_orgIndustry.*?onSaved:\s*\(v\)\s*=>\s*_orgIndustry.*?,\s*\)", dotAll: true);
  
  var newDropdown = '''DropdownButtonFormField<String>(
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
        )''';

  content = content.replaceFirst(regex, newDropdown);
  file.writeAsStringSync(content);
}
