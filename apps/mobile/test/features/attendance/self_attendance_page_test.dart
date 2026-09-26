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
import 'package:dailio/features/attendance/models/attendance_models.dart';
import 'package:dailio/features/attendance/pages/self_attendance_page.dart';

ApiClient _apiClient(PreferencesStorage preferences) => ApiClient(
      baseUrl: 'https://test.invalid',
      authInterceptor: AuthInterceptor(
        SecureStorage(const FlutterSecureStorage()),
      ),
      tenantInterceptor: TenantInterceptor(preferences),
    );

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository(ApiClient apiClient) : super(apiClient: apiClient);

  bool isOpen = false;
  bool failClockIn = false;

  AttendanceSessionModel get _session => AttendanceSessionModel(
        id: 'session-1',
        state: isOpen ? 'OPEN' : 'CLOSED',
        clockInServerTime: DateTime.utc(2026, 9, 26, 8),
        clockOutServerTime: isOpen ? null : DateTime.utc(2026, 9, 26, 16),
        workedMinutes: isOpen ? null : 480,
        policyVersion: 1,
        source: 'SELF',
      );

  @override
  Future<Map<String, dynamic>> getAttendancePolicy(String locationId) async => {
        'version': 1,
        'source_scope': 'BRANCH_DEFAULT',
        'late_grace_minutes': 15,
        'location_on_clock_in': false,
        'location_on_clock_out': false,
        'selfie_on_clock_in': false,
        'selfie_on_clock_out': false,
        'geofence_enabled': false,
        'shift_enforcement_enabled': false,
      };

  @override
  Future<AttendanceSessionModel?> getActiveSession(String locationId) async =>
      isOpen ? _session : null;

  @override
  Future<List<AttendanceSessionModel>> getSessions(
    String locationId,
    String period, {
    String? roleId,
    String? dateFrom,
    String? dateTo,
  }) async =>
      isOpen ? [_session] : const [];

  @override
  Future<AttendanceSessionModel> clockIn(
    String locationId, {
    required String idempotencyKey,
    int? policyVersion,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? selfieStorageKey,
    String? selfieUploadToken,
    String? selfieContentType,
    int? selfieSizeBytes,
  }) async {
    if (failClockIn) {
      throw Exception('The attendance policy rejected this punch');
    }
    isOpen = true;
    return _session;
  }

  @override
  Future<AttendanceSessionModel> clockOut(
    String locationId,
    String sessionId, {
    required String idempotencyKey,
    int? policyVersion,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? selfieStorageKey,
    String? selfieUploadToken,
    String? selfieContentType,
    int? selfieSizeBytes,
  }) async {
    isOpen = false;
    return _session;
  }
}

Future<(PreferencesStorage, _FakeAttendanceRepository)> _setup() async {
  SharedPreferences.setMockInitialValues({
    'active_branch_id': 'branch-1',
    'active_branch_name': 'Barari',
  });
  final preferences = PreferencesStorage(
    await SharedPreferences.getInstance(),
  );
  final repository = _FakeAttendanceRepository(_apiClient(preferences));
  return (preferences, repository);
}

Widget _page(
  PreferencesStorage preferences,
  _FakeAttendanceRepository repository,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: preferences),
      Provider<AttendanceRepository>.value(value: repository),
    ],
    child: const MaterialApp(home: SelfAttendancePage()),
  );
}

void main() {
  testWidgets('manual self attendance moves from clock-in to open session',
      (tester) async {
    final (preferences, repository) = await _setup();

    await tester.pumpWidget(_page(preferences, repository));
    await tester.pumpAndSettle();

    expect(find.text('Clock in'), findsOneWidget);
    await tester.tap(find.text('Clock in'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.isOpen, isTrue);
    expect(find.text('Clock-in submitted and confirmed.'), findsOneWidget);
  });

  testWidgets('manual self attendance confirms clock-out', (tester) async {
    final (preferences, repository) = await _setup();
    repository.isOpen = true;

    await tester.pumpWidget(_page(preferences, repository));
    await tester.pumpAndSettle();

    expect(find.text('Clock out'), findsOneWidget);
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(find.text('Clock out'));
    await tester.pumpAndSettle();

    expect(repository.isOpen, isFalse);
    expect(find.text('Clock-out submitted and confirmed.'), findsOneWidget);
  });

  testWidgets('manual self attendance shows a retryable failure state',
      (tester) async {
    final (preferences, repository) = await _setup();
    repository.failClockIn = true;

    await tester.pumpWidget(_page(preferences, repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clock in'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Attendance submission failed.'), findsOneWidget);
    expect(
      find.text(
          'We could not complete that attendance action. Please try again.'),
      findsOneWidget,
    );
  });
}
