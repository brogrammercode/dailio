import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../features/auth/pages/onboarding_page.dart';
import '../../features/context_selection/pages/join_or_create_page.dart';
import '../../features/context_selection/pages/organization_discovery_page.dart';
import '../../features/context_selection/pages/org_detail_page.dart';
import '../../features/context_selection/models/branch_discovery_model.dart';
import '../../features/context_selection/pages/pending_join_page.dart';
import '../../features/branch/pages/configure_member_page.dart';
import '../../features/branch/pages/subscription_plans_page.dart';
import '../../features/branch/pages/shift_management_page.dart';
import '../../features/branch/pages/payroll_management_page.dart';
import '../../features/context_selection/pages/context_switcher_page.dart';
import '../../features/organization/pages/create_organization_page.dart';
import '../../features/organization/pages/create_branch_page.dart';
import '../../features/organization/models/create_organization_models.dart';
import '../../features/branch/pages/members_page.dart';
import '../../features/branch/pages/member_detail_page.dart';
import '../../features/branch/pages/join_requests_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../widgets/app_shell.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(String initialLocation) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    debugLogDiagnostics: true,
    routes: [
      
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
        path: AppRoutes.orgDetail,
        builder: (_, state) {
          final locations = state.extra as List<BranchDiscoveryModel>?;
          return OrgDetailPage(locations: locations ?? []);
        },
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
        path: AppRoutes.createBranch,
        builder: (_, state) {
          final input = state.extra as CreateOrganizationInput;
          return CreateBranchPage(organizationInput: input);
        },
      ),
      // â”€â”€ Main app shell with bottom nav â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const AppShell(),
      ),
      // Sub-routes pushed on top of the shell (full-screen pages)
      GoRoute(
        path: AppRoutes.members,
        builder: (_, __) => const MembersPage(),
      ),
      GoRoute(
        path: AppRoutes.memberDetail,
        builder: (_, state) => MemberDetailPage(
          membershipId: state.pathParameters['memberId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.joinRequests,
        builder: (_, __) => const JoinRequestsPage(),
      ),
      // â”€â”€ Shared routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfilePage(),
      ),
    ],
  );
}


