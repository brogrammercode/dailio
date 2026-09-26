import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dailio_overflow_menu.dart';

/// The shared two-line roster/ledger row used by Attendance, Fees and Payments.
class DailioCompactTile extends StatelessWidget {
  final Widget avatar;
  final String title;
  final String? titleBadge;
  final String? statusBadge;
  final Color? statusBadgeColor;
  final String subtitle;
  final String trailing;
  final List<DailioMenuItem<String>> menuItems;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color subtitleColor;

  const DailioCompactTile({
    super.key,
    required this.avatar,
    required this.title,
    this.titleBadge,
    this.statusBadge,
    this.statusBadgeColor,
    required this.subtitle,
    required this.trailing,
    required this.menuItems,
    required this.onMenuSelected,
    this.onTap,
    this.onLongPress,
    this.subtitleColor = const Color(0xFF6B6B6B),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.brandDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (titleBadge != null && titleBadge!.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: _badge(
                              titleBadge!,
                              AppColors.brandAccent,
                            ),
                          ),
                        ],
                        if (statusBadge != null && statusBadge!.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: _badge(
                              statusBadge!,
                              statusBadgeColor ?? AppColors.brandAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 104),
                    child: Text(
                      trailing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: DailioOverflowMenu<String>(
                      items: menuItems,
                      onSelected: onMenuSelected,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
