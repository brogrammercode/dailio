import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/error/app_exception.dart';
import '../../organization/controllers/organization_repository.dart';
import '../controllers/auth_cubit.dart';
import '../controllers/auth_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        await context.read<PreferencesStorage>().clearContext();
        if (!mounted) return;
        context.go(AppRoutes.joinOrCreate);
        return;
      }
      final preferences = context.read<PreferencesStorage>();
      final activeMembership =
          _findActiveMembership(organizations, preferences);
      if (activeMembership == null) {
        await preferences.clearContext();
        if (!mounted) return;
        context.go(AppRoutes.contextSwitcher);
      } else {
        await preferences.setActiveContext(
          organizationId: activeMembership.organizationId,
          branchId: activeMembership.branchId,
          organizationName: activeMembership.organizationName,
          branchName: activeMembership.branchName,
          branchTimezone: activeMembership.branchTimezone,
          roleSystemKey: activeMembership.roleSystemKey,
          permissions: activeMembership.permissions,
        );
        if (!mounted) return;
        context.go(AppRoutes.home);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRouting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_signInErrorMessage(error))),
      );
    }
  }

  _ActiveMembership? _findActiveMembership(
    List<Map<String, dynamic>> organizations,
    PreferencesStorage preferences,
  ) {
    final organizationId = preferences.activeOrganizationId;
    final branchId = preferences.activeBranchId;
    if (organizationId == null || branchId == null) return null;

    for (final organizationEntry in organizations) {
      final organization = organizationEntry['organization'];
      if (organization is! Map ||
          organization['id']?.toString() != organizationId) {
        continue;
      }
      final memberships = organizationEntry['location_memberships'];
      if (memberships is! List) continue;

      for (final rawMembership in memberships) {
        if (rawMembership is! Map) continue;
        final location = rawMembership['location'];
        if (location is! Map || location['id']?.toString() != branchId) {
          continue;
        }
        final role = rawMembership['role'];
        final roleMap = role is Map ? Map<String, dynamic>.from(role) : null;
        final rawPermissions = roleMap?['permissions'];
        return _ActiveMembership(
          organizationId: organizationId,
          branchId: branchId,
          organizationName: organization['name']?.toString(),
          branchName: location['name']?.toString(),
          branchTimezone: location['timezone']?.toString(),
          roleSystemKey: roleMap?['system_key']?.toString(),
          permissions: rawPermissions is List
              ? rawPermissions
                  .map((permission) => permission.toString())
                  .toList()
              : const <String>[],
        );
      }
    }
    return null;
  }

  // Keep provider/transport details out of the login screen. The actual
  // Google/API failure is already represented by AuthError in the login UI.
  String _signInErrorMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Could not load your workspaces. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _LoginBackground.color,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) _handleAuthenticated();
        },
        child: const _LoginBackground(child: _LoginContent()),
      ),
    );
  }
}

class _ActiveMembership {
  const _ActiveMembership({
    required this.organizationId,
    required this.branchId,
    this.organizationName,
    this.branchName,
    this.branchTimezone,
    this.roleSystemKey,
    required this.permissions,
  });

  final String organizationId;
  final String branchId;
  final String? organizationName;
  final String? branchName;
  final String? branchTimezone;
  final String? roleSystemKey;
  final List<String> permissions;
}

class _LoginContent extends StatelessWidget {
  const _LoginContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final horizontalPadding = (width * .08).clamp(24.0.r, 48.0.r);
          final logoWidth = (width * .74).clamp(240.0.r, 320.0.r);
          final headlineSize = (width * .098).clamp(31.0.r, 48.0.r);
          final compact = height < 700;

          return BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final loading = state is AuthLoading ||
                  context
                          .findAncestorStateOfType<_OnboardingPageState>()
                          ?._isRouting ==
                      true;
              final error = state is AuthError ? state.message : null;

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 22.r : height * .085,
                  horizontalPadding,
                  compact ? 24.r : 34.r,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, height - (compact ? 46.r : 119.r)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DailioLogo(width: logoWidth),
                      SizedBox(height: compact ? 25.r : height * .035),
                      Text(
                        'SMART\nATTENDANCE\nIS HERE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: headlineSize,
                          height: .99,
                          fontWeight: FontWeight.w800,
                          letterSpacing: (-1.3).r,
                        ),
                      ),
                      SizedBox(height: compact ? 14.r : 22.r),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 360.r),
                        child: Text(
                          'Attendance, memberships,\nschedules, and operations\nin one clean platform.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .82),
                            fontSize: (width * .048).clamp(16.0.r, 22.0.r),
                            height: 1.3,
                            fontWeight: FontWeight.w400,
                            letterSpacing: (-.25).r,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? 105.r
                            : (height * .275).clamp(145.0.r, 570.0.r),
                      ),
                      if (error != null) ...[
                        _LoginError(message: error),
                        SizedBox(height: 14.r),
                      ],
                      _GoogleSignInButton(
                        loading: loading,
                        onPressed: () =>
                            context.read<AuthCubit>().signInWithGoogle(),
                      ),
                      SizedBox(height: 26.r),
                      const _LegalCopy(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground({required this.child});

  static const color = Color(0xFF080C11);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color,
      body: CustomPaint(
        painter: _LoginBackgroundPainter(),
        child: child,
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _LoginBackground.color,
    );

    _drawGlow(
      canvas,
      size,
      center: Offset(size.width * 1.08, size.height * .03),
      radius: size.width * 1.05,
      strength: .95,
    );
    _drawGlow(
      canvas,
      size,
      center: Offset(size.width * 1.09, size.height * .97),
      radius: size.width * 1.1,
      strength: .9,
    );

    _drawArcs(
      canvas,
      size,
      center: Offset(size.width * 1.08, size.height * .02),
      startRadius: size.width * .55,
      count: 5,
      step: size.width * .15,
    );
    _drawArcs(
      canvas,
      size,
      center: Offset(size.width * 1.08, size.height * .98),
      startRadius: size.width * .56,
      count: 6,
      step: size.width * .15,
    );
  }

  void _drawGlow(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required double strength,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (center.dx / size.width) * 2 - 1,
          (center.dy / size.height) * 2 - 1,
        ),
        radius: radius / math.max(size.width, size.height),
        colors: [
          AppColors.brandAccent.withValues(alpha: .74 * strength),
          AppColors.brandAccent.withValues(alpha: .25 * strength),
          Colors.transparent,
        ],
        stops: const [.02, .28, .8],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawArcs(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double startRadius,
    required int count,
    required double step,
  }) {
    for (var index = 0; index < count; index++) {
      final radius = startRadius + (index * step);
      final opacity = .52 - (index * .065);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = index == 0 ? 1.35.r : 1.r
        ..color =
            AppColors.brandAccent.withValues(alpha: opacity.clamp(.12, .52));
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, math.pi * .48, math.pi * .52, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DailioLogo extends StatelessWidget {
  const _DailioLogo({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * .34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
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
      height: 64.r,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34.r),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(34.r),
          splashColor: AppColors.brandAccent.withValues(alpha: .12),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22.r,
                    height: 22.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4.r,
                      color: Color(0xFF11151B),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GoogleMark(),
                      SizedBox(width: 16.r),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: Color(0xFF11151B),
                          fontSize: 17.r,
                          fontWeight: FontWeight.w700,
                          letterSpacing: (-.2).r,
                        ),
                      ),
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
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
          Color(0xFF4285F4),
        ],
      ).createShader(bounds),
      child: Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28.r,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 11.r),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1518).withValues(alpha: .9),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFFF807A).withValues(alpha: .35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.danger, color: Color(0xFFFFA39D), size: 18.r),
          SizedBox(width: 9.r),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Color(0xFFFFD8D5),
                fontSize: 12.r,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1.r),
          child: Icon(
            Iconsax.tick_square,
            color: Colors.white,
            size: 22.r,
          ),
        ),
        SizedBox(width: 13.r),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'By continuing, you agree to our ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .88),
                fontSize: 14.r,
                height: 1.45,
              ),
              children: const [
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Terms of Service.',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
