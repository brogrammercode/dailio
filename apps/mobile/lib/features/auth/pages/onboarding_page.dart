import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../organization/controllers/organization_repository.dart';
import '../controllers/auth_cubit.dart';
import '../controllers/auth_state.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _isRouting = false;

  Future<void> _handleAuthenticated() async {
    if (!mounted) return;
    setState(() => _isRouting = true);
    try {
      final organizations =
          await context.read<OrganizationRepository>().getMyOrganizations();
      if (!mounted) return;
      if (organizations.isEmpty) {
        context.go(AppRoutes.joinOrCreate);
        return;
      }
      final preferences = context.read<PreferencesStorage>();
      if (preferences.activeOrganizationId == null ||
          preferences.activeBranchId == null) {
        context.go(AppRoutes.contextSwitcher);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRouting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not finish sign-in. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _handleAuthenticated();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final loading = state is AuthLoading || _isRouting;
              final error = state is AuthError ? state.message : null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  const _LoginHero(),
                  const SizedBox(height: 26),
                  const Text(
                    'Welcome to Dailio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'One simple workspace for everyday operations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF858585)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7EF),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFFFE0C2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Iconsax.people,
                            color: Color(0xFFCC5A00), size: 19),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Join your organization or create one in a few steps.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF68401F),
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (error != null) ...[
                    Text(error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFB3261E))),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: loading
                          ? null
                          : () => context.read<AuthCubit>().signInWithGoogle(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF202020),
                        side: const BorderSide(color: Color(0xFFE1E1E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFCC5A00)),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('G',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4285F4))),
                                SizedBox(width: 10),
                                Text('Continue with Google',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'By continuing, you accept the Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Color(0xFF929292)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 294,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF171717)),
          child: Stack(
            children: [
              Positioned(
                top: -98,
                right: -72,
                child: _HeroCircle(
                  size: 270,
                  color: const Color(0xFFCC5A00).withValues(alpha: 0.16),
                  borderColor: const Color(0xFFFF8A00).withValues(alpha: 0.34),
                ),
              ),
              Positioned(
                top: -42,
                right: -16,
                child: _HeroCircle(
                  size: 164,
                  color: Colors.transparent,
                  borderColor: const Color(0xFFFF8A00).withValues(alpha: 0.24),
                ),
              ),
              Positioned(
                left: -92,
                bottom: -116,
                child: _HeroCircle(
                  size: 250,
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.035),
                  borderColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Image.asset('assets/logo.png'),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dailio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'EVERYDAY, IN SYNC',
                              style: TextStyle(
                                color: Color(0xFFFFA15C),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(Iconsax.more,
                            color: Colors.white.withValues(alpha: 0.68),
                            size: 21),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Keep every day\nmoving.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        height: 1.04,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'People, payments and attendance —\nin one calm workspace.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.67),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Expanded(
                          child: _HeroFeature(
                            icon: Iconsax.activity,
                            label: 'Attendance',
                            value: 'Live',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _HeroFeature(
                            icon: Iconsax.wallet_3,
                            label: 'Operations',
                            value: 'Simple',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({
    required this.size,
    required this.color,
    required this.borderColor,
  });

  final double size;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1),
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFA15C), size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 10)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
