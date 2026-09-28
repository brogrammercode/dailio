import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import 'dailio_overflow_menu.dart';

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

  const DailioSimpleAppBar({
    super.key,
    this.onBack,
    this.menuItems = const [],
    this.onMenuSelected,
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
      title: const Text(
        'Dailio',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      actions: [
        if (menuItems.isNotEmpty)
          DailioOverflowMenu<String>(
            items: menuItems,
            onSelected: onMenuSelected ?? (_) {},
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
