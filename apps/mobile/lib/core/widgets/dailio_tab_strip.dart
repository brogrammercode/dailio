import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A compact, scrollable text tab strip used by list screens.
class DailioTabItem<T> {
  final T value;
  final String label;

  const DailioTabItem({required this.value, required this.label});
}

class DailioTabStyles {
  DailioTabStyles._();

  static final selectedText = TextStyle(
    color: AppColors.brandAccent,
    fontSize: 12.r,
    fontWeight: FontWeight.w700,
  );
  static final unselectedText = TextStyle(
    color: Color(0xFF6B6B6B),
    fontSize: 12.r,
    fontWeight: FontWeight.w500,
  );
  static final horizontalPadding = EdgeInsets.symmetric(horizontal: 12.r);
  static final tabPadding = EdgeInsets.symmetric(horizontal: 8.r);
}

class DailioTabStrip<T> extends StatelessWidget {
  final List<DailioTabItem<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool centered;

  const DailioTabStrip({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final tabRow = Row(
      // Keep the centered strip intrinsic so its baseline ends with the last
      // tab instead of stretching across the viewport.
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final tab = entry.value;
        final active = tab.value == selected;
        return InkWell(
          onTap: () => onChanged(tab.value),
          child: Container(
            height: 44.r,
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 4.r,
              right: 4.r,
            ),
            padding: DailioTabStyles.tabPadding,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.brandAccent : Colors.transparent,
                  width: 2.r,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              tab.label,
              style: active
                  ? DailioTabStyles.selectedText
                  : DailioTabStyles.unselectedText,
            ),
          ),
        );
      }).toList(),
    );

    if (centered) {
      return SizedBox(
        height: 44.r,
        child: ColoredBox(
          color: Colors.white,
          child: Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE9E9E9)),
                ),
              ),
              child: tabRow,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E9))),
      ),
      child: SizedBox(
        height: 44.r,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: DailioTabStyles.horizontalPadding,
          child: tabRow,
        ),
      ),
    );
  }
}
