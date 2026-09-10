class AppRoutes {
  AppRoutes._();

  
  static const String onboarding = '/onboarding';
  static const String signIn = '/sign-in';
  static const String joinOrCreate = '/join-or-create';
  static const String createOrganization = '/create-gym';
  static const String createBranch = '/create-branch';
  static const String organizationDiscovery = '/discover';
  static const String branchSelection = '/branches';
  static const String pendingJoin = '/pending';
  static const String contextSwitcher = '/switch';
  static const String orgDetail = '/org-detail/:orgId';

  // Owner/Admin shell
  static const String home = '/home';
  static const String attendance = '/home/attendance';
  static const String attendanceDetail = '/home/attendance/:session_id';
  static const String fees = '/home/fees';
  static const String subscriptionDetail = '/home/fees/:subscription_id';
  static const String branch = '/home/branch';
  static const String members = '/home/branch/members';
  static const String memberDetail = '/home/branch/members/:memberId';
  static const String joinRequests = '/home/branch/join-requests';
  static const String roles = '/home/branch/roles';
  static const String plans = '/home/branch/plans';
  static const String newAdmission = '/home/branch/new-admission';

  // Shared
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String announcements = '/announcements';
}

