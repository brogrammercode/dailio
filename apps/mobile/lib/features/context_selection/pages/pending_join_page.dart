import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
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
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _checkApproval(silent: true));
    Future.delayed(const Duration(seconds: 2), _checkApproval);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApproval({bool silent = false}) async {
    if (!mounted || _isChecking) return;
    setState(() => _isChecking = true);
    try {
      final organizations =
          await context.read<OrganizationRepository>().getMyOrganizations();
      if (!mounted) return;
      final prefs = context.read<PreferencesStorage>();
      if (organizations.isNotEmpty) {
        if (prefs.activeOrganizationId == null ||
            prefs.activeBranchId == null) {
          final firstOrganization = organizations.first;
          final memberships =
              (firstOrganization['location_memberships'] as List?) ?? [];
          if (memberships.isNotEmpty) {
            final firstMembership =
                Map<String, dynamic>.from(memberships.first as Map);
            final branch =
                Map<String, dynamic>.from(firstMembership['location'] as Map);
            final role =
                (firstMembership['role'] as Map?)?.cast<String, dynamic>();
            await prefs.setActiveContext(
              organizationId: firstOrganization['organization']['id'],
              branchId: branch['id'],
              organizationName: firstOrganization['organization']['name'],
              branchName: branch['name'],
              branchTimezone: branch['timezone']?.toString(),
              roleSystemKey: role?['system_key']?.toString(),
              permissions: (role?['permissions'] as List?)?.cast<String>(),
            );
          }
        }
        if (!mounted) return;
        _pollTimer?.cancel();
        context.go(AppRoutes.home);
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your request is still waiting for approval.')));
      }
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not check status. Please try again.')));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (_, state) {
        if (state is AuthAuthenticated) _checkApproval(silent: true);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: DailioSimpleAppBar(
            onBack: () => context.go(AppRoutes.joinOrCreate)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              const Text('Request pending',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('The branch owner needs to approve your membership.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF858585))),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE0C2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Iconsax.clock, color: Color(0xFFCC5A00), size: 21),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'You can check again after the owner reviews your request. Access will appear automatically once approved.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF68401F),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              DailioOnboardingButton(
                label: 'Check approval status',
                icon: Iconsax.refresh,
                loading: _isChecking,
                onPressed: _checkApproval,
              ),
              const SizedBox(height: 10),
              DailioOnboardingButton(
                label: 'Back to join or create',
                outlined: true,
                onPressed: () => context.go(AppRoutes.joinOrCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
