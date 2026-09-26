import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/di/injection.dart';
import 'core/storage/preferences_storage.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/api_client.dart';
import 'core/network/interceptors/auth_interceptor.dart';
import 'core/network/interceptors/tenant_interceptor.dart';
import 'core/router/route_names.dart';

import 'features/auth/controllers/auth_repository.dart';
import 'features/context_selection/controllers/branch_repository.dart';
import 'features/branch/controllers/admission_repository.dart';
import 'features/branch/controllers/members_repository.dart';
import 'features/branch/controllers/shift_repository.dart';
import 'features/branch/controllers/payroll_repository.dart';
import 'features/organization/controllers/organization_repository.dart';
import 'features/attendance/controllers/attendance_repository.dart';
import 'features/fees/controllers/fees_repository.dart';

Future<bool> _restoreActiveContext(
  PreferencesStorage preferences,
  List<Map<String, dynamic>> organizations,
) async {
  final organizationId = preferences.activeOrganizationId;
  final branchId = preferences.activeBranchId;
  if (organizationId == null || branchId == null) return false;

  for (final organizationEntry in organizations) {
    if (organizationEntry['organization']?['id']?.toString() !=
        organizationId) {
      continue;
    }

    final memberships = organizationEntry['location_memberships'];
    if (memberships is! List) return false;
    for (final entry in memberships) {
      if (entry is! Map) continue;
      final location = entry['location'];
      if (location is! Map || location['id']?.toString() != branchId) {
        continue;
      }

      final role = entry['role'] is Map
          ? Map<String, dynamic>.from(entry['role'] as Map)
          : null;
      final rawPermissions = role?['permissions'];
      final permissions = rawPermissions is List
          ? rawPermissions.map((permission) => permission.toString()).toList()
          : <String>[];

      await preferences.setActiveContext(
        organizationId: organizationId,
        branchId: branchId,
        organizationName:
            organizationEntry['organization']?['name']?.toString(),
        branchName: location['name']?.toString(),
        roleSystemKey: role?['system_key']?.toString(),
        permissions: permissions,
      );
      return true;
    }
  }

  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  configureDependencies();

  // Set up global Bloc observer
  Bloc.observer = AppBlocObserver();

  // Initialize storage
  final prefs = await SharedPreferences.getInstance();
  final secureStorage = SecureStorage(const FlutterSecureStorage());
  final preferencesStorage = PreferencesStorage(prefs);

  final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';
  final String apiEndpoint = '$baseUrl/api/v1';

  final apiClient = ApiClient(
    baseUrl: apiEndpoint,
    authInterceptor: AuthInterceptor(secureStorage),
    tenantInterceptor: TenantInterceptor(preferencesStorage),
  );

  final authRepository = AuthRepository(apiClient, secureStorage);
  final branchRepository = BranchRepository(apiClient: apiClient);
  final admissionRepository = AdmissionRepository(apiClient: apiClient);
  final organizationRepository = OrganizationRepository(apiClient: apiClient);
  final membersRepository = MembersRepository(apiClient: apiClient);
  final shiftRepository = ShiftRepository(apiClient);
  final payrollRepository = PayrollRepository(apiClient);
  final attendanceRepository = AttendanceRepository(apiClient: apiClient);
  final feesRepository = FeesRepository(apiClient: apiClient);

  String initialRoute = AppRoutes.onboarding;

  try {
    final token = await secureStorage.getAccessToken();
    if (token != null) {
      final user = await authRepository.getMe();
      if (user != null) {
        final orgs = await organizationRepository.getMyOrganizations();
        if (orgs.isEmpty) {
          initialRoute = AppRoutes.joinOrCreate;
        } else {
          final restored =
              await _restoreActiveContext(preferencesStorage, orgs);
          if (!restored) {
            initialRoute = AppRoutes.contextSwitcher;
          } else {
            initialRoute = AppRoutes.home;
          }
        }
      } else {
        await secureStorage.clearTokens();
      }
    }
  } catch (e) {
    final token = await secureStorage.getAccessToken();
    if (token != null) {
      if (preferencesStorage.activeOrganizationId == null ||
          preferencesStorage.activeBranchId == null) {
        initialRoute = AppRoutes.contextSwitcher;
      } else {
        initialRoute = AppRoutes.home;
      }
    }
  }

  runApp(
    MainApp(
      secureStorage: secureStorage,
      preferencesStorage: preferencesStorage,
      apiClient: apiClient,
      authRepository: authRepository,
      branchRepository: branchRepository,
      admissionRepository: admissionRepository,
      organizationRepository: organizationRepository,
      membersRepository: membersRepository,
      shiftRepository: shiftRepository,
      payrollRepository: payrollRepository,
      attendanceRepository: attendanceRepository,
      feesRepository: feesRepository,
      initialRoute: initialRoute,
    ),
  );
}
