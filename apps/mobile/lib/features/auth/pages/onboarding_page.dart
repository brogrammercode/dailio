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
  Future<void> _handleAuthenticated() async {
    // PRESERVE EXISTING LOGIC - do not change this
    try {
      final repo = context.read<OrganizationRepository>();
      final orgs = await repo.getMyOrganizations();
      if (orgs.isEmpty) {
        if (mounted) context.go(AppRoutes.joinOrCreate);
      } else {
        if (mounted) {
          final prefs = context.read<PreferencesStorage>();
          if (prefs.activeOrganizationId == null || prefs.activeBranchId == null) {
            context.go(AppRoutes.contextSwitcher);
            return;
          }
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              final isLoading = state is AuthLoading;
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 48),
                          // App icon
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3D1F00),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Center(
                              child: Text('Dailio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Dailio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 6),
                          const Text(
                            'Enterprise Workforce & Location Intelligence',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 48),
                          // Network visualization with feature labels
                          SizedBox(
                            height: 300,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Radar chart
                                CustomPaint(size: const Size(220, 220), painter: _NetworkPainter()),
                                // Feature labels positioned around the viz
                                const Positioned(
                                  top: 10, right: 20,
                                  child: _FeatureLabel('99.9% Verified Attendance', Icons.check_circle_outline, Color(0xFF22C55E)),
                                ),
                                const Positioned(
                                  top: 70, left: 0,
                                  child: _FeatureLabel('HQ • 14 Branches Active', Icons.radio_button_checked, Color(0xFFB45309)),
                                ),
                                const Positioned(
                                  bottom: 80, left: 10,
                                  child: _FeatureLabel('Multi-tenant Isolation', Icons.grid_view_rounded, Color(0xFFB45309)),
                                ),
                                const Positioned(
                                  bottom: 48, right: 30,
                                  child: _FeatureLabel('Role-based Access', Icons.shield_outlined, Color(0xFF6B7280)),
                                ),
                                const Positioned(
                                  bottom: 10, left: 30,
                                  child: _FeatureLabel('Zero Trust Geofenced Clock-ins', null, Color(0xFF6B7280), extraIcons: [Icons.navigation_outlined, Icons.lock_outlined]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom auth section
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state is AuthError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => context.read<AuthCubit>().signInWithGoogle(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A1A1A),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
                            ),
                            child: isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const _GoogleIcon(),
                                      const SizedBox(width: 12),
                                      const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text.rich(
                          TextSpan(
                            text: "By signing in, you agree to Dailio's ",
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            children: [
                              TextSpan(text: 'Terms of Service', style: TextStyle(decoration: TextDecoration.underline, color: Color(0xFF4B5563))),
                              TextSpan(text: ' and\n'),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(decoration: TextDecoration.underline, color: Color(0xFF4B5563))),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_outline, size: 13, color: Color(0xFF9CA3AF)),
                            SizedBox(width: 4),
                            Text('Enterprise SSO • Audit Trail v2.4', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                        const SizedBox(height: 24),
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

class _FeatureLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final List<IconData> extraIcons;
  const _FeatureLabel(this.text, this.icon, this.color, {this.extraIcons = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (extraIcons.isNotEmpty)
            ...extraIcons.map((ic) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(ic, size: 14, color: color),
                ))
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 14, color: color),
            ),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text('G', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4285F4))),
    );
  }
}

class _NetworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radii = [40.0, 80.0, 120.0];

    // Dashed circle helper
    final dashPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final r in radii) {
      _drawDashedCircle(canvas, center, r, dashPaint);
    }

    // Lines
    final line1 = Paint()..color = const Color(0xFFB45309)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final line2 = Paint()..color = const Color(0xFF9CA3AF)..strokeWidth = 1.2..style = PaintingStyle.stroke;

    canvas.drawLine(center, Offset(center.dx + 120 * cos(30 * pi / 180), center.dy - 120 * sin(30 * pi / 180)), line1);
    canvas.drawLine(center, Offset(center.dx - 80 * cos(20 * pi / 180), center.dy + 80 * sin(200 * pi / 180)), line1);
    canvas.drawLine(center, Offset(center.dx + 110, center.dy + 20), line2);
    canvas.drawLine(center, Offset(center.dx - 30, center.dy + 110), line2);

    // Dots
    void dot(Offset pos, Color color, double r) {
      canvas.drawCircle(pos, r, Paint()..color = color);
    }
    dot(center, const Color(0xFF3D1F00), 10);
    dot(Offset(center.dx + 100 * cos(30 * pi / 180), center.dy - 100 * sin(30 * pi / 180)), const Color(0xFFB45309), 7);
    dot(Offset(center.dx - 70 * cos(20 * pi / 180), center.dy + 70 * sin(70 * pi / 180)), const Color(0xFF22C55E), 7);
    dot(Offset(center.dx + 108, center.dy + 18), const Color(0xFF9CA3AF), 5);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashCount = 24;
    const dashAngle = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      final startAngle = i * dashAngle;
      final endAngle = (i + 1) * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, endAngle - startAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
