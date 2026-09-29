import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
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
        content: Text('Could not finish sign-in. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _handleAuthenticated();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              return BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final loading = state is AuthLoading || _isRouting;
                  final error = state is AuthError ? state.message : null;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      compact ? 14 : 22,
                      18,
                      20,
                    ),
                    children: [
                      _LoginHero(compact: compact),
                      SizedBox(height: compact ? 22 : 28),
                      Text(
                        'Start with Dailio.',
                        style: textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF17120E),
                          fontSize: compact ? 24 : 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your people, plans and progress — in sync.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF817A75),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 22),
                      if (error != null) ...[
                        _LoginError(message: error),
                        const SizedBox(height: 12),
                      ],
                      _GoogleSignInButton(
                        loading: loading,
                        onPressed: () =>
                            context.read<AuthCubit>().signInWithGoogle(),
                      ),
                      const SizedBox(height: 13),
                      const _TrustRow(),
                      const SizedBox(height: 18),
                      const _LegalCopy(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 264 : 306,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF1A1715)),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -112,
                right: -72,
                child: _GlowCircle(
                  size: 250,
                  fill: AppColors.brandAccent.withValues(alpha: .22),
                  stroke: AppColors.brandAccent.withValues(alpha: .35),
                ),
              ),
              Positioned(
                right: -24,
                bottom: -110,
                child: _GlowCircle(
                  size: 210,
                  fill: Colors.transparent,
                  stroke: Colors.white.withValues(alpha: .08),
                ),
              ),
              Positioned(
                left: -108,
                bottom: -142,
                child: _GlowCircle(
                  size: 270,
                  fill: Colors.white.withValues(alpha: .025),
                  stroke: Colors.white.withValues(alpha: .07),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HeroBrandRow(),
                    const Spacer(),
                    Text(
                      'Run the day.\nKeep it simple.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 29 : 33,
                        height: 1.02,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A calmer way to manage everyday operations.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .64),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: compact ? 15 : 20),
                    const _WorkspacePreview(),
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

class _HeroBrandRow extends StatelessWidget {
  const _HeroBrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        const Text(
          'Dailio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.activity, color: Color(0xFFFFA15C), size: 13),
              SizedBox(width: 5),
              Text(
                'IN SYNC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkspacePreview extends StatelessWidget {
  const _WorkspacePreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _PreviewTile(
            icon: Iconsax.activity,
            label: 'Attendance',
            value: 'Live',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _PreviewTile(
            icon: Iconsax.people,
            label: 'Members',
            value: 'Together',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _PreviewTile(
            icon: Iconsax.wallet_3,
            label: 'Payments',
            value: 'Clear',
          ),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
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
      padding: const EdgeInsets.fromLTRB(9, 9, 6, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFFA15C), size: 15),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .56),
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.fill,
    required this.stroke,
  });

  final double size;
  final Color fill;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: stroke),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: const Color(0xFF191512),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.brandAccent.withValues(alpha: .2),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GoogleMark(),
                      SizedBox(width: 11),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Iconsax.arrow_right_3,
                          color: Color(0xFFFFA15C), size: 17),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Iconsax.shield_tick, size: 15, color: AppColors.brandAccent),
        const SizedBox(width: 6),
        Text(
          'Secure sign-in · no password to remember',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8B8580),
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD7D2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.danger, color: Color(0xFFB3261E), size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8D2D27),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalCopy extends StatelessWidget {
  const _LegalCopy();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'By continuing, you agree to Dailio’s ',
        style: const TextStyle(
          color: Color(0xFF9B9590),
          fontSize: 10,
          height: 1.35,
        ),
        children: const [
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: AppColors.brandDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: AppColors.brandDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
