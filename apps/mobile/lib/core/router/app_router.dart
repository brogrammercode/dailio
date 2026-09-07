import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/splash_page.dart';
import '../../features/auth/pages/onboarding_page.dart';
import '../../features/context_selection/pages/join_or_create_page.dart';
import '../../features/context_selection/pages/organization_discovery_page.dart';
import '../../features/context_selection/pages/pending_join_page.dart';
import '../../features/context_selection/pages/context_switcher_page.dart';
import '../../features/organization/pages/create_organization_page.dart';
import '../../features/attendance/pages/attendance_page.dart';
import '../../features/fees/pages/fees_page.dart';
import '../../features/branch/pages/branch_page.dart';
import '../../features/branch/pages/members_page.dart';
import '../../features/branch/pages/join_requests_page.dart';
import '../../features/profile/pages/profile_page.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.joinOrCreate,
        builder: (_, __) => const JoinOrCreatePage(),
      ),
      GoRoute(
        path: AppRoutes.organizationDiscovery,
        builder: (_, __) => const OrganizationDiscoveryPage(),
      ),
      GoRoute(
        path: AppRoutes.pendingJoin,
        builder: (_, __) => const PendingJoinPage(),
      ),
      GoRoute(
        path: AppRoutes.contextSwitcher,
        builder: (_, __) => const ContextSwitcherPage(),
      ),
      GoRoute(
        path: AppRoutes.createOrganization,
        builder: (_, __) => const CreateOrganizationPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const _HomeShell(),
        routes: [
          GoRoute(
            path: 'attendance',
            builder: (_, __) => const AttendancePage(),
          ),
          GoRoute(
            path: 'fees',
            builder: (_, __) => const FeesPage(),
          ),
          GoRoute(
            path: 'branch',
            builder: (_, __) => const BranchPage(),
            routes: [
              GoRoute(
                path: 'members',
                builder: (_, __) => const MembersPage(),
              ),
              GoRoute(
                path: 'join-requests',
                builder: (_, __) => const JoinRequestsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfilePage(),
      ),
    ],
  );
}

class _HomeShell extends StatelessWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context) {
    return const AttendancePage(); // Default home tab
  }
}
