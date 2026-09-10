import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences_storage.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_cubit.dart';
import 'features/auth/controllers/auth_repository.dart';
import 'features/context_selection/controllers/branch_repository.dart';
import 'features/branch/controllers/admission_repository.dart';
import 'features/branch/controllers/members_repository.dart';
import 'features/organization/controllers/organization_repository.dart';
import 'features/attendance/controllers/attendance_repository.dart';

class MainApp extends StatefulWidget {
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final BranchRepository branchRepository;
  final AdmissionRepository admissionRepository;
  final OrganizationRepository organizationRepository;
  final MembersRepository membersRepository;
  final AttendanceRepository attendanceRepository;
  final String initialRoute;

  const MainApp({
    super.key,
    required this.secureStorage,
    required this.preferencesStorage,
    required this.apiClient,
    required this.authRepository,
    required this.branchRepository,
    required this.admissionRepository,
    required this.organizationRepository,
    required this.membersRepository,
    required this.attendanceRepository,
    required this.initialRoute,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Cache the router so hot reload doesn't reset the navigation stack
    _router = buildRouter(widget.initialRoute);
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.preferencesStorage),
        RepositoryProvider.value(value: widget.branchRepository),
        RepositoryProvider.value(value: widget.admissionRepository),
        RepositoryProvider.value(value: widget.organizationRepository),
        RepositoryProvider.value(value: widget.membersRepository),
        RepositoryProvider.value(value: widget.attendanceRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(widget.authRepository),
          ),
        ],
        child: MaterialApp.router(
          title: 'Dailio',
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
