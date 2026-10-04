import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import 'dailio_overflow_menu.dart';
import 'dailio_notification_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The standard top bar for secondary Dailio pages.
///
/// The page identity stays intentionally simple: Dailio, a back affordance
/// when the page is pushed, and the same compact overflow menu used by the
/// primary list screens.
class DailioSimpleAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback? onBack;
  final List<DailioMenuItem<String>> menuItems;
  final ValueChanged<String>? onMenuSelected;
  final PreferredSizeWidget? bottom;

  const DailioSimpleAppBar({
    super.key,
    this.onBack,
    this.menuItems = const [],
    this.onMenuSelected,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.brandDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: onBack == null
          ? null
          : IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Iconsax.arrow_left_2),
            ),
      title: Text(
        'Dailio',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.r),
      ),
      actions: [
        const DailioNotificationButton(),
        if (menuItems.isNotEmpty)
          DailioOverflowMenu<String>(
            items: menuItems,
            onSelected: onMenuSelected ?? (_) {},
          ),
        SizedBox(width: 8.r),
      ],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}
