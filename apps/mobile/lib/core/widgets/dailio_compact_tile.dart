import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dailio_overflow_menu.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  final VoidCallback? onAvatarTap;
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
    this.onAvatarTap,
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
          padding: EdgeInsets.fromLTRB(16.r, 9.r, 8.r, 9.r),
          child: Row(
            children: [
              _avatarWithAction(),
              SizedBox(width: 10.r),
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
                            style: TextStyle(
                              color: AppColors.brandDark,
                              fontSize: 14.r,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (titleBadge != null && titleBadge!.isNotEmpty) ...[
                          SizedBox(width: 7.r),
                          Flexible(
                            child: _badge(
                              titleBadge!,
                              AppColors.brandAccent,
                            ),
                          ),
                        ],
                        if (statusBadge != null && statusBadge!.isNotEmpty) ...[
                          SizedBox(width: 5.r),
                          Flexible(
                            child: _badge(
                              statusBadge!,
                              statusBadgeColor ?? AppColors.brandAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.r),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11.r,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.r),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 104.r),
                    child: Text(
                      trailing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 10.r,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 28.r,
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

  Widget _avatarWithAction() {
    if (onAvatarTap == null) return avatar;
    return Semantics(
      button: true,
      label: 'Open profile',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAvatarTap,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 3.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9.r,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
