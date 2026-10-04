import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/controllers/auth_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class JoinOrCreatePage extends StatelessWidget {
  const JoinOrCreatePage({super.key});

  Future<void> _showSignOutConfirmation(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to access Dailio.',
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Iconsax.logout,
    );
    if (confirmed != true || !context.mounted) return;
    final preferences = context.read<PreferencesStorage>();
    final authCubit = context.read<AuthCubit>();
    await preferences.clearContext();
    await authCubit.signOut();
    if (context.mounted) context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
              value: 'signout', icon: Iconsax.logout, label: 'Sign out'),
        ],
        onMenuSelected: (value) {
          if (value == 'signout') _showSignOutConfirmation(context);
        },
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.r, 18.r, 16.r, 32.r),
          children: [
            Text('Start with Dailio',
                style: TextStyle(fontSize: 22.r, fontWeight: FontWeight.w800)),
            SizedBox(height: 5.r),
            Text(
              'Choose how you want to enter your first workspace.',
              style: TextStyle(fontSize: 13.r, color: Color(0xFF858585)),
            ),
            SizedBox(height: 22.r),
            const DailioOnboardingSectionLabel('GET STARTED'),
            DailioOnboardingChoiceRow(
              title: 'Create an organization',
              subtitle: 'Set up your organization and first branch.',
              icon: Iconsax.building_4,
              onTap: () => context.push(AppRoutes.createOrganization),
            ),
            Divider(height: 1.r),
            DailioOnboardingChoiceRow(
              title: 'Join an organization',
              subtitle: 'Find your organization and request branch access.',
              icon: Iconsax.search_normal_1,
              onTap: () => context.push(AppRoutes.organizationDiscovery),
            ),
            SizedBox(height: 20.r),
            DailioOnboardingButton(
              label: 'Scan and fast join',
              icon: Iconsax.scan_barcode,
              outlined: true,
              onPressed: () => context.push(AppRoutes.qrScanner),
            ),
            SizedBox(height: 20.r),
            Text(
              'Joining an organization sends a request to the branch owner. You will get access after approval.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.r, color: Color(0xFF929292)),
            ),
          ],
        ),
      ),
    );
  }
}
