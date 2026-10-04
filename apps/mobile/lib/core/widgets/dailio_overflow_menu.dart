import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A compact, consistent overflow menu for Dailio screens.
///
/// Keeping the menu shape and row treatment here prevents every screen from
/// growing a different version of the same three-dot interaction.
class DailioMenuItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
  final bool enabled;

  const DailioMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.enabled = true,
  });
}

class DailioOverflowMenu<T> extends StatelessWidget {
  final List<DailioMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;

  const DailioOverflowMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.tooltip = 'More options',
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      splashRadius: 22.r,
      icon: const Icon(Icons.more_horiz, color: AppColors.brandDark),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8.r,
      constraints: BoxConstraints(minWidth: 188.r, maxWidth: 248.r),
      offset: Offset(0, 8.r),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              height: 44.r,
              padding: EdgeInsets.symmetric(horizontal: 14.r),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 18.r,
                    color: item.destructive
                        ? AppColors.error
                        : AppColors.brandDark,
                  ),
                  SizedBox(width: 11.r),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: item.destructive
                          ? AppColors.error
                          : AppColors.brandDark,
                      fontSize: 13.r,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
