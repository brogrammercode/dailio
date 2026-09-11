import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../auth/controllers/auth_cubit.dart';

class JoinOrCreatePage extends StatelessWidget {
  const JoinOrCreatePage({super.key});

  Future<void> _showSignOutConfirmation(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool isSigningOut = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Sign Out',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF1A1A1A))),
              content: const Text(
                'Are you sure you want to sign out? You will need to sign in again to access workspaces.',
                style: TextStyle(
                    color: Color(0xFF4B5563), fontSize: 14, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isSigningOut
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSigningOut
                      ? null
                      : () async {
                          setState(() => isSigningOut = true);
                          try {
                            await context
                                .read<PreferencesStorage>()
                                .clearContext();
                            if (context.mounted) {
                              await context.read<AuthCubit>().signOut();
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (context.mounted) {
                              context.go(AppRoutes.onboarding);
                            }
                          }
                        },
                  child: isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Sign Out',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
            onSelected: (value) {
              if (value == 'signout') {
                _showSignOutConfirmation(context);
              }
            },
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Iconsax.logout, size: 20, color: Color(0xFFDC2626)),
                    SizedBox(width: 12),
                    Text('Sign Out',
                        style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/logo.png', width: 64, height: 64),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to Dailio',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You don\'t belong to any active workspace yet. Choose an option below to get started.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Option 1: Create
              _buildOptionCard(
                context: context,
                title: 'Create an Organization',
                description:
                    'Set up a new multi-tenant workspace, configure your branches, and invite your workforce.',
                icon: Icons.domain_add,
                iconColor: const Color(0xFFB45309),
                iconBg: const Color(0xFFFFF7ED),
                onTap: () => context.push(AppRoutes.createOrganization),
              ),
              const SizedBox(height: 16),

              // Option 2: Join
              _buildOptionCard(
                context: context,
                title: 'Join an Organization',
                description:
                    'Search for your employer\'s workspace and send a request to join your specific branch.',
                icon: Icons.search,
                iconColor: const Color(0xFF22C55E),
                iconBg: const Color(0xFFF0FDF4),
                onTap: () => context.push(AppRoutes.organizationDiscovery),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Iconsax.arrow_right_3, color: Color(0xFFD1D5DB)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
