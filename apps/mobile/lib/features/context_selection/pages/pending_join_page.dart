import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../auth/controllers/auth_cubit.dart';
import '../../auth/controllers/auth_state.dart';
import '../../organization/controllers/organization_repository.dart';

class PendingJoinPage extends StatefulWidget {
  const PendingJoinPage({super.key});

  @override
  State<PendingJoinPage> createState() => _PendingJoinPageState();
}

class _PendingJoinPageState extends State<PendingJoinPage> {
  Timer? _pollTimer;
  int _dotCount = 0;
  int _checkCount = 0;

  @override
  void initState() {
    super.initState();
    // Animate the dots
    Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
    // Poll for membership approval every 15 seconds
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkApproval());
    // Check immediately on mount too
    Future.delayed(const Duration(seconds: 3), _checkApproval);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApproval() async {
    if (!mounted) return;
    _checkCount++;

    try {
      final repo = context.read<OrganizationRepository>();
      final orgs = await repo.getMyOrganizations();

      if (!mounted) return;

      // If user now has an active membership, route them home
      if (orgs.isNotEmpty) {
        _pollTimer?.cancel();
        final prefs = context.read<PreferencesStorage>();
        // Auto-select the first available org+branch if not already set
        if (prefs.activeOrganizationId == null ||
            prefs.activeBranchId == null) {
          final firstOrg = orgs.first;
          final locationMemberships =
              firstOrg['location_memberships'] as List? ?? [];
          if (locationMemberships.isNotEmpty) {
            final firstBranch =
                locationMemberships.first['location'] as Map<String, dynamic>?;
            if (firstBranch != null) {
              await prefs.setActiveContext(
                organizationId: firstOrg['organization']['id'],
                branchId: firstBranch['id'],
                organizationName: firstOrg['organization']['name'],
                branchName: firstBranch['name'],
                branchTimezone: firstBranch['timezone']?.toString(),
                roleSystemKey:
                    (locationMemberships.first['role'] as Map?)?['system_key']
                        ?.toString(),
                permissions: ((locationMemberships.first['role']
                        as Map?)?['permissions'] as List?)
                    ?.cast<String>(),
              );
            }
          }
        }
        if (mounted) context.go(AppRoutes.home);
      }
    } catch (_) {
      // Silently ignore network errors during polling
    }
  }

  @override
  Widget build(BuildContext context) {
    // Also listen for FCM-triggered auth state refresh
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _checkApproval();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF0F2F5),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
              onPressed: () => context.go(AppRoutes.joinOrCreate),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFDE68A), width: 4),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      size: 48, color: Color(0xFFD97706)),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Approval Pending',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your request to join the organization has been sent. You will be notified once the branch manager or admin approves your admission.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Checking for approval${_checkCount > 0 ? " ($_checkCount checks)" : ""}${"." * _dotCount}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _checkApproval,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF92400E),
                        side: const BorderSide(color: Color(0xFF92400E)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Check Now',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.joinOrCreate),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4B5563),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Go Back',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
