import 'package:iconsax/iconsax.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_cubit.dart';
import '../controllers/auth_state.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';

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
      if (mounted) {
        setState(() => _isRouting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        context.read<AuthCubit>().signOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _handleAuthenticated();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLoading = (state is AuthLoading) || _isRouting;
              return Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // App icon
                                Image.asset(
                                  'assets/logo.png',
                                  width: 64,
                                  height: 64,
                                ),
                                const SizedBox(height: 16),
                                const Text('Dailio',
                                    style: TextStyle(
                                        fontSize: 28,
                                        letterSpacing: -1.0,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A))),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enterprise Workforce & Location Intelligence',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                      height: 1.4),
                                ),
                                const SizedBox(height: 32),

                                // THE NEW SUPER CREATIVE VISUALIZATION (Scaled Down & Centered)
                                const _HeroVisualizer(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom auth section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state is AuthError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(state.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFDC2626), fontSize: 13)),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () => context
                                    .read<AuthCubit>()
                                    .signInWithGoogle(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A1A1A),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                      color: Color(0xFFE5E7EB), width: 1.5)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFFB45309))),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                          'https://cdn-icons-png.flaticon.com/512/281/281764.png',
                                          width: 20,
                                          height: 20),
                                      const SizedBox(width: 12),
                                      const Text('Continue with Google',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                            'By continuing, you accept the Terms of Service and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                      ],
                    ),
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

// ----------------------------------------------------------------------
// SCALED DOWN HERO VISUALIZER
// ----------------------------------------------------------------------
class _HeroVisualizer extends StatefulWidget {
  const _HeroVisualizer();
  @override
  State<_HeroVisualizer> createState() => _HeroVisualizerState();
}

class _HeroVisualizerState extends State<_HeroVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280, // Reduced height so footer doesn't need scrolling
      width:
          320, // Constrained width to perfectly cluster the elements around the center
      child: Stack(
        clipBehavior: Clip.none, // Prevent cropping
        alignment: Alignment.center,
        children: [
          // 1. Faded Tech Grid Background
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent
                  ],
                  stops: const [0.2, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
          ),

          // 2. Pulsing Glow Orb
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse = sin(_controller.value * pi * 2);
              return Transform.scale(
                scale: 1.0 + (pulse * 0.08),
                child: Container(
                  width: 140, // Scaled down
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFB45309).withValues(alpha: 0.1),
                        const Color(0xFFB45309).withValues(alpha: 0.0),
                      ],
                      stops: const [0.2, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. Central Core Icon
          Container(
            width: 60, // Scaled down
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF3F4F6), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB45309).withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 4,
                )
              ],
            ),
            child: const Center(
              child: Icon(Iconsax.building, color: Color(0xFFB45309), size: 24),
            ),
          ),

          // 4. Floating Glassmorphism Feature Cards
          // Repositioned to stay strictly within the 320x280 frame safely
          _FloatingCard(
            controller: _controller,
            delayOffset: 0.0,
            top: 20,
            left: 0,
            icon: Icons.hub,
            label: 'Multi-Tenant',
          ),
          _FloatingCard(
            controller: _controller,
            delayOffset: 1.5,
            top: 60,
            right: 0,
            icon: Icons.share_location,
            label: 'Geofenced',
          ),
          _FloatingCard(
            controller: _controller,
            delayOffset: 3.14,
            bottom: 60,
            left: 0,
            icon: Icons.shield_outlined,
            label: 'Role-Based Access',
          ),
          _FloatingCard(
            controller: _controller,
            delayOffset: 4.5,
            bottom: 20,
            right: 0,
            icon: Iconsax.wallet_3,
            label: 'Live Payroll',
          ),
        ],
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final AnimationController controller;
  final double delayOffset;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final IconData icon;
  final String label;

  const _FloatingCard({
    required this.controller,
    required this.delayOffset,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final offset = sin((controller.value * 2 * pi) + delayOffset) *
              8.0; // Reduced amplitude
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8), // Scaled down padding
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius:
                BorderRadius.circular(10), // Scaled down border radius
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFB45309).withValues(alpha: 0.05),
                blurRadius: 6,
                spreadRadius: -2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon,
                    size: 14,
                    color: const Color(0xFFB45309)), // Scaled down icon
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11, // Scaled down font size
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    const double step = 24.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
