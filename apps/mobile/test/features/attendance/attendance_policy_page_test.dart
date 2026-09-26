import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:dailio/core/network/api_client.dart';
import 'package:dailio/core/network/interceptors/auth_interceptor.dart';
import 'package:dailio/core/network/interceptors/tenant_interceptor.dart';
import 'package:dailio/core/storage/preferences_storage.dart';
import 'package:dailio/core/storage/secure_storage.dart';
import 'package:dailio/features/attendance/controllers/attendance_repository.dart';
import 'package:dailio/features/organization/controllers/organization_repository.dart';
import 'package:dailio/features/organization/pages/attendance_policy_page.dart';
import 'package:dailio/features/branch/controllers/members_repository.dart';

ApiClient _apiClient(PreferencesStorage preferences) => ApiClient(
      baseUrl: 'https://test.invalid',
      authInterceptor: AuthInterceptor(
        SecureStorage(const FlutterSecureStorage()),
      ),
      tenantInterceptor: TenantInterceptor(preferences),
    );

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository(ApiClient apiClient) : super(apiClient: apiClient);

  @override
  Future<List<Map<String, dynamic>>> getAttendancePolicies(
    String locationId,
  ) async {
    return [
      {
        'id': 'policy-1',
        'version': 1,
        'role_id': null,
        'member_id': null,
        'punch_required': true,
        'effective_from': '2026-09-01T00:00:00.000Z',
        'effective_to': null,
        'affected_member_count': 2,
      },
    ];
  }
}

class _FakeOrganizationRepository extends OrganizationRepository {
  _FakeOrganizationRepository(ApiClient apiClient)
      : super(apiClient: apiClient);

  @override
  Future<List<Map<String, dynamic>>> getRoles(
    String organizationId, {
    String? branchId,
  }) async {
    return [
      {'id': 'role-1', 'name': 'Coach'},
    ];
  }
}

class _FakeMembersRepository extends MembersRepository {
  _FakeMembersRepository(ApiClient apiClient) : super(apiClient: apiClient);

  @override
  Future<Map<String, dynamic>> listMembers(
    String branchId, {
    String? search,
    String? status,
    String? roleId,
    int page = 1,
    int limit = 20,
  }) async {
    return {
      'data': [
        {
          'id': 'member-1',
          'user': {'name': 'Adarsh'},
        },
      ],
    };
  }
}

void main() {
  test('policy error surfaces hide unknown provider details', () {
    expect(
      attendancePolicyErrorMessage(Exception('database password leaked')),
      'We could not complete that attendance action. Please try again.',
    );
  });

  testWidgets(
      'policy assignment controls expose branch, role, and member scopes',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_organization_id': 'org-1',
      'active_branch_id': 'branch-1',
      'active_permissions': '["ATTENDANCE_POLICY_MANAGE"]',
    });
    final preferences = PreferencesStorage(
      await SharedPreferences.getInstance(),
    );
    final apiClient = _apiClient(preferences);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: preferences),
          Provider<AttendanceRepository>(
            create: (_) => _FakeAttendanceRepository(apiClient),
          ),
          Provider<OrganizationRepository>(
            create: (_) => _FakeOrganizationRepository(apiClient),
          ),
          Provider<MembersRepository>(
            create: (_) => _FakeMembersRepository(apiClient),
          ),
        ],
        child: const MaterialApp(home: AttendancePolicyPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Policy assignment'), findsOneWidget);
    expect(find.text('Branch default'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('A role'), findsOneWidget);
    expect(find.text('One member'), findsOneWidget);
  });
}
