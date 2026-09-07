import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controllers/auth_cubit.dart';
import '../../features/auth/controllers/auth_state.dart';
import '../../features/attendance/pages/attendance_page.dart';
import '../../features/fees/pages/fees_page.dart';
import '../../features/branch/pages/branch_page.dart';
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
    BranchPage(),
  ];

  final _labels = const ['Attendance', 'Fees', 'Branch'];

  final _icons = const [
    Icons.punch_clock_outlined,
    Icons.receipt_long_outlined,
    Icons.location_city_outlined,
  ];

  final _activeIcons = const [
    Icons.punch_clock,
    Icons.receipt_long,
    Icons.location_city,
  ];

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<PreferencesStorage>();
    final orgName = prefs.activeOrganizationName ?? 'My Organization';
    final branchName = prefs.activeBranchName;

    return Scaffold(
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
          // Context switcher
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Location',
            onPressed: () => context.push(AppRoutes.contextSwitcher),
          ),
          // Profile avatar
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
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.profile),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 13,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: List.generate(
          _labels.length,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_activeIcons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
