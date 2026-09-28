import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailio/core/network/api_client.dart';
import 'package:dailio/core/network/interceptors/auth_interceptor.dart';
import 'package:dailio/core/network/interceptors/tenant_interceptor.dart';
import 'package:dailio/core/storage/preferences_storage.dart';
import 'package:dailio/core/storage/secure_storage.dart';
import 'package:dailio/features/organization/controllers/organization_repository.dart';
import 'package:dailio/features/organization/pages/roles_permissions_page.dart';

class _FakeOrganizationRepository extends OrganizationRepository {
  _FakeOrganizationRepository(ApiClient apiClient)
      : super(apiClient: apiClient);

  @override
  Future<List<Map<String, dynamic>>> getOrganizationBranches(
    String orgId,
  ) async {
    return [
      {'id': 'branch-1', 'name': 'Barari'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getRoles(
    String orgId, {
    String? branchId,
  }) async {
    return [
      {
        'id': 'role-1',
        'organization_id': orgId,
        'name': 'Member',
        'branch_id': null,
        'system_key': 'MEMBER',
        'is_protected': true,
        'is_system': true,
        'permissions': ['ATTENDANCE_READ_SELF'],
      },
    ];
  }
}

ApiClient _apiClient(PreferencesStorage preferences) => ApiClient(
      baseUrl: 'https://test.invalid',
      authInterceptor: AuthInterceptor(
        SecureStorage(const FlutterSecureStorage()),
      ),
      tenantInterceptor: TenantInterceptor(preferences),
    );

void main() {
  testWidgets('roles page renders role tabs without a layout exception',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_organization_id': 'org-1',
      'active_branch_id': 'branch-1',
    });
    final preferences = PreferencesStorage(
      await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: preferences),
          Provider<OrganizationRepository>(
            create: (_) => _FakeOrganizationRepository(_apiClient(preferences)),
          ),
        ],
        child: const MaterialApp(home: RolesPermissionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Member (1)'), findsOneWidget);
  });
}
