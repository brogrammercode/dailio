import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/network/api_client.dart';
import 'core/network/interceptors/auth_interceptor.dart';
import 'core/network/interceptors/tenant_interceptor.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences_storage.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_cubit.dart';
import 'features/auth/controllers/auth_repository.dart';
import 'features/context_selection/controllers/location_repository.dart';
import 'features/branch/controllers/admission_repository.dart';
import 'features/branch/controllers/members_repository.dart';
import 'features/organization/controllers/organization_repository.dart';
import 'features/attendance/controllers/attendance_repository.dart';

class MainApp extends StatelessWidget {
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;

  const MainApp({
    super.key,
    required this.secureStorage,
    required this.preferencesStorage,
  });

  @override
  Widget build(BuildContext context) {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';
    final String apiEndpoint = '$baseUrl/api/v1';

    final apiClient = ApiClient(
      baseUrl: apiEndpoint,
      authInterceptor: AuthInterceptor(secureStorage),
      tenantInterceptor: TenantInterceptor(preferencesStorage),
    );

    final authRepository = AuthRepository(apiClient, secureStorage);
    final locationRepository = LocationRepository(apiClient: apiClient);
    final admissionRepository = AdmissionRepository(apiClient: apiClient);
    final organizationRepository = OrganizationRepository(apiClient: apiClient);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: preferencesStorage),
        RepositoryProvider.value(value: locationRepository),
        RepositoryProvider.value(value: admissionRepository),
        RepositoryProvider.value(value: organizationRepository),
        RepositoryProvider.value(value: MembersRepository(apiClient: apiClient)),
        RepositoryProvider.value(value: AttendanceRepository(apiClient: apiClient)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(authRepository),
          ),
        ],
        child: MaterialApp.router(
          title: 'Organization Management',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: buildRouter(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
