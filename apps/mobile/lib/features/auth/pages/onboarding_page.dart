import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_cubit.dart';
import '../controllers/auth_state.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/storage/preferences_storage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
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
            // Fallback: set the first org as active.
            // In a full implementation, you'd fetch the locations for this org and set the first location.
            // For MVP, we'll set the org ID and leave branch ID null, or redirect to context_switcher.
            // Since we must have a location, redirecting to context switcher is safer if we don't know it.
            context.go(AppRoutes.contextSwitcher);
            return;
          }
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking context: $e')));
        context.read<AuthCubit>().signOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _handleAuthenticated();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (state is AuthLoading) {
                  return const LoadingWidget(message: 'Signing in...');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Icon(Icons.fitness_center, size: 96),
                    const SizedBox(height: 32),
                    Text(
                      'Organization Management',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage your organization, members, attendance and fees — all in one place.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    if (state is AuthError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          (state).message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: () =>
                          context.read<AuthCubit>().signInWithGoogle(),
                      icon: const Icon(Icons.login),
                      label: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
