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
          if (preferencesStorage.activeOrganizationId == null ||
              preferencesStorage.activeBranchId == null) {
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
      initialRoute: initialRoute,
    ),
  );
}
