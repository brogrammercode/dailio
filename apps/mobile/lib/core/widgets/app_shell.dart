import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../storage/preferences_storage.dart';
import '../theme/app_colors.dart';
import 'app_shell_toast.dart';
import 'dailio_nav_badges.dart';

import '../../features/attendance/pages/attendance_page.dart';
import '../../features/announcements/pages/announcements_page.dart';
import '../../features/fees/pages/fees_page.dart';
import '../../features/payments/pages/payments_page.dart';
import '../../features/settings/pages/settings_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _badgeKeys = [
    'announcements',
    'attendance',
    '',
    'payments',
    '',
  ];
  int _currentIndex = 0;
  String? _lastContextKey;

  final _labels = const [
    'Announcements',
    'Attendance',
    'Fees',
    'Payments',
    'Settings'
  ];

  final _icons = const [
    Iconsax.message_text,
    Iconsax.clock,
    Iconsax.receipt,
    Iconsax.wallet_3,
    Iconsax.setting_2,
  ];

  final _activeIcons = const [
    Iconsax.message_text,
    Iconsax.clock,
    Iconsax.receipt,
    Iconsax.wallet_3,
    Iconsax.setting_2,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences = context.read<PreferencesStorage>();
    final contextKey =
        '${preferences.activeOrganizationId}:${preferences.activeBranchId}';
    if (_lastContextKey != null && _lastContextKey != contextKey) {
      DailioNavBadgeController.reset();
    }
    _lastContextKey = contextKey;
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<PreferencesStorage>();
    final contextKey =
        '${preferences.activeOrganizationId}:${preferences.activeBranchId}';
    final pages = [
      AnnouncementsPage(key: ValueKey('announcements-$contextKey')),
      AttendancePage(key: ValueKey('attendance-$contextKey')),
      FeesPage(key: ValueKey('fees-$contextKey')),
      PaymentsPage(key: ValueKey('payments-$contextKey')),
      SettingsPage(key: ValueKey('settings-$contextKey')),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          const AppShellToast(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.r, 0, 24.r, 16.r),
          child: Container(
            height: 58.r,
            padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 6.r),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.r),
              borderRadius: BorderRadius.circular(30.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24.r,
                  offset: Offset(0, 10.r),
                ),
              ],
            ),
            child: ValueListenableBuilder<Map<String, int>>(
              valueListenable: DailioNavBadgeController.counts,
              builder: (context, badges, _) => Row(
                children: List.generate(
                  _labels.length,
                  (index) => _BottomNavButton(
                    isActive: _currentIndex == index,
                    icon: _icons[index],
                    activeIcon: _activeIcons[index],
                    label: _labels[index],
                    badge: _badgeKeys[index].isEmpty
                        ? null
                        : badges[_badgeKeys[index]],
                    onTap: () => setState(() => _currentIndex = index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final bool isActive;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.isActive,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.brandAccent : const Color(0xFF6B7280);
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(24.r),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46.r,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFFFF1E6) : Colors.transparent,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    size: isActive ? 22.r : 20.r,
                    color: color,
                  ),
                  if (badge != null && badge! > 0)
                    Positioned(
                      top: (-8).r,
                      right: (-11).r,
                      child: Container(
                        constraints: BoxConstraints(minWidth: 16.r),
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.r, vertical: 2.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(9.r),
                          border: Border.all(color: Colors.white, width: 1.5.r),
                        ),
                        child: Text(
                          badge! > 99 ? '99+' : '$badge',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.r,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
