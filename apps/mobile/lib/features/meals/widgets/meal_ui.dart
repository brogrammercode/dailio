import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';

class MealUi {
  MealUi._();

  static const canvas = Color(0xFFF9F9F8);
  static const muted = Color(0xFF777777);
  static const border = Color(0xFFE7E7E5);
  static const positive = Color(0xFF1C9A5F);
  static const negative = Color(0xFFD64545);

  static InputDecoration inputDecoration({
    String? label,
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
      labelStyle: TextStyle(fontSize: 12.r, color: MealUi.muted),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 16.r, color: const Color(0xFF8A8A8A)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 13.r),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5.r),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: negative),
      ),
    );
  }

  static Widget fieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.r),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class MealSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const MealSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 14.r,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 3.r),
                  Text(
                    subtitle!,
                    style: TextStyle(color: MealUi.muted, fontSize: 10.r),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class MealPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const MealPanel({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: MealUi.border),
      ),
      child: child,
    );
  }
}

class MealSlotMark extends StatelessWidget {
  final String label;
  final bool marked;
  final bool compact;

  const MealSlotMark({
    super.key,
    required this.label,
    required this.marked,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = marked ? MealUi.positive : MealUi.negative;
    return Tooltip(
      message: '$label: ${marked ? 'marked' : 'not marked'}',
      child: Container(
        width: compact ? 16.r : 22.r,
        height: compact ? 16.r : 22.r,
        margin: EdgeInsets.only(right: compact ? 4.r : 6.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.42)),
        ),
        child: Icon(
          marked ? Iconsax.tick_circle : Iconsax.close_circle,
          size: compact ? 10.r : 13.r,
          color: color,
        ),
      ),
    );
  }
}
