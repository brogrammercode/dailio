import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_cubit.dart';
import '../controllers/auth_state.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().checkSession();
  }

  Future<void> _handleAuthenticated() async {
    try {
      final repo = context.read<OrganizationRepository>();
      final orgs = await repo.getMyOrganizations();
      if (orgs.isEmpty) {
        if (mounted) context.go(AppRoutes.joinOrCreate);
      } else {
        if (mounted) {
          final prefs = context.read<PreferencesStorage>();
          if (prefs.activeOrganizationId == null ||
              prefs.activeBranchId == null) {
            context.go(AppRoutes.contextSwitcher);
            return;
          }
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _handleAuthenticated();
        } else if (state is AuthUnauthenticated || state is AuthError) {
          context.go(AppRoutes.onboarding);
        }
      },
      child: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 80),
              SizedBox(height: 24),
              Text(
                'Organization Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
