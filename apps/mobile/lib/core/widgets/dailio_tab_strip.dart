import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A compact, scrollable text tab strip used by list screens.
class DailioTabItem<T> {
  final T value;
  final String label;

  const DailioTabItem({required this.value, required this.label});
}

class DailioTabStyles {
  DailioTabStyles._();

  static const selectedText = TextStyle(
    color: AppColors.brandAccent,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
  static const unselectedText = TextStyle(
    color: Color(0xFF6B6B6B),
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  static const horizontalPadding = EdgeInsets.symmetric(horizontal: 12);
  static const tabPadding = EdgeInsets.symmetric(horizontal: 8);
}

class DailioTabStrip<T> extends StatelessWidget {
  final List<DailioTabItem<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  const DailioTabStrip({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E9))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: DailioTabStyles.horizontalPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final active = tab.value == selected;
            return InkWell(
              onTap: () => onChanged(tab.value),
              child: Container(
                height: 44,
                margin: EdgeInsets.only(
                  left: index == 0 ? 0 : 4,
                  right: 4,
                ),
                padding: DailioTabStyles.tabPadding,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          active ? AppColors.brandAccent : Colors.transparent,
                      width: 2,
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
        ),
      ),
    );
  }
}
