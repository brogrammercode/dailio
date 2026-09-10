import 'dart:io';

void main() {
  var file = File('apps/mobile/lib/features/organization/models/create_organization_models.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    "'timezone': timezone,",
    "'timezone': timezone.split(' ').first,"
  );
  content = content.replaceAll(
    "'currency': currency,",
    "'currency': currency.substring(0, 3),"
  );
  
  file.writeAsStringSync(content);
}
