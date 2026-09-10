import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controllers/auth_cubit.dart';
import '../../features/auth/controllers/auth_state.dart';
import '../../features/attendance/pages/attendance_page.dart';
import '../../features/fees/pages/fees_page.dart';
import '../../features/payments/pages/payments_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../router/route_names.dart';
import '../storage/preferences_storage.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _pages = const [
    AttendancePage(),
    FeesPage(),
    PaymentsPage(),
    SettingsPage(),
  ];

  final _labels = const ['Attendance', 'Fees', 'Payments', 'Settings'];

  final _icons = const [
    Iconsax.clock,
    Iconsax.receipt,
    Iconsax.wallet_3,
    Iconsax.setting_2,
  ];

  final _activeIcons = const [
    Iconsax.clock,
    Iconsax.receipt,
    Iconsax.wallet_3,
    Iconsax.setting_2,
  ];

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<PreferencesStorage>();
    final orgName = prefs.activeOrganizationName ?? 'My Organization';
    final branchName = prefs.activeBranchName;

    return Scaffold(
      extendBody: true, // Allows the body to flow underneath the floating nav bar
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(orgName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (branchName != null)
              Text(branchName, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.repeat),
            tooltip: 'Switch Location',
            onPressed: () => context.push(AppRoutes.contextSwitcher),
          ),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final initials = state is AuthAuthenticated
                  ? state.user.name
                      .trim()
                      .split(' ')
                      .map((w) => w.isEmpty ? '' : w[0])
                      .take(2)
                      .join()
                      .toUpperCase()
                  : '?';
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.profile),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List.generate(
                _labels.length,
                (index) => _BottomNavButton(
                  isActive: _currentIndex == index,
                  icon: _icons[index],
                  activeIcon: _activeIcons[index],
                  label: _labels[index],
                  onTap: () => setState(() => _currentIndex = index),
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
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.isActive,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF4F46E5) : const Color(0xFF6B7280); // Indigo vs Gray
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFEEF2FF) // Light Indigo BG
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: isActive ? 22 : 20,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
