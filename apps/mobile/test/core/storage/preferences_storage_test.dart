import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailio/core/storage/preferences_storage.dart';

void main() {
  test('persists and clears the active organization type', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());

    await storage.setActiveContext(
      organizationId: 'org-1',
      branchId: 'branch-1',
      organizationType: 'FOOD_SERVICE',
    );

    expect(storage.activeOrganizationType, 'FOOD_SERVICE');

    await storage.clearContext();

    expect(storage.activeOrganizationType, isNull);
  });

  test('owner context is treated as the server-granted ALL bypass', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());

    await storage.setActiveContext(
      organizationId: 'org-1',
      branchId: 'branch-1',
      roleSystemKey: 'OWNER',
    );

    expect(storage.hasPermission('MEAL_MANAGE'), isTrue);
    expect(storage.hasPermission('PAYMENT_WAIVE'), isTrue);
  });
}
