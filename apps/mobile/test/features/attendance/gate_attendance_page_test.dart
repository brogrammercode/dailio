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
import 'package:dailio/features/attendance/controllers/attendance_repository.dart';
import 'package:dailio/features/attendance/pages/gate_attendance_page.dart';

ApiClient _apiClient(PreferencesStorage preferences) => ApiClient(
      baseUrl: 'https://test.invalid',
      authInterceptor: AuthInterceptor(
        SecureStorage(const FlutterSecureStorage()),
      ),
      tenantInterceptor: TenantInterceptor(preferences),
    );

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository(ApiClient apiClient) : super(apiClient: apiClient);
}

void main() {
  test('gate requirement preview follows the server action policy', () {
    final policy = {
      'location_on_clock_in': true,
      'location_on_clock_out': false,
      'selfie_on_clock_in': false,
      'selfie_on_clock_out': true,
      'geofence_enabled': true,
      'shift_enforcement_enabled': true,
    };

    expect(
      gateAttendanceRequirementLabels(policy, clockOut: false),
      ['Location capture', 'Geofence validation', 'Shift window'],
    );
    expect(
      gateAttendanceRequirementLabels(policy, clockOut: true),
      [
        'Location capture',
        'Live selfie',
        'Geofence validation',
        'Shift window'
      ],
    );
  });

  testWidgets('gallery-resolved gate QR cannot submit attendance',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesStorage(
      await SharedPreferences.getInstance(),
    );
    final apiClient = _apiClient(preferences);

    await tester.pumpWidget(
      Provider<AttendanceRepository>.value(
        value: _FakeAttendanceRepository(apiClient),
        child: MaterialApp(
          home: GateAttendancePage(
            token: 'permanent-gate-token',
            invite: {
              'attendance_action': 'CLOCK_OUT',
              'scan_from_gallery': true,
              'branch': {'id': 'branch-1', 'name': 'Barari'},
              'attendance_policy': {
                'selfie_on_clock_out': true,
                'location_on_clock_out': true,
              },
            },
          ),
        ),
      ),
    );

    expect(find.text('Next action: Clock out'), findsOneWidget);
    expect(find.text('Confirm clock out'), findsOneWidget);
    await tester.tap(find.text('Confirm clock out'));
    await tester.pump();

    expect(
      find.textContaining('must be scanned live with the camera'),
      findsOneWidget,
    );
  });
}
