import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppShellToastData {
  final String message;
  final IconData icon;

  const AppShellToastData({
    required this.message,
    required this.icon,
  });
}

/// Global, non-blocking status strip rendered by [AppShell].
///
/// It is intentionally persistent and compact, unlike a SnackBar: screen
/// actions can update it without interrupting the current interaction.
class AppShellToastController {
  AppShellToastController._();

  static final ValueNotifier<AppShellToastData?> value =
      ValueNotifier<AppShellToastData?>(null);

  static void show(String message, {IconData icon = Icons.info_outline}) {
    value.value = AppShellToastData(message: message, icon: icon);
  }

  static void clear() => value.value = null;
}

class AppShellToast extends StatelessWidget {
  const AppShellToast({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppShellToastData?>(
      valueListenable: AppShellToastController.value,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return Positioned(
          left: 16.r,
          right: 88.r,
          bottom: 84.r,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Container(
                key: ValueKey(data.message),
                height: 32.r,
                padding: EdgeInsets.symmetric(horizontal: 11.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12.r,
                      offset: Offset(0, 4.r),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(data.icon, size: 14.r, color: AppColors.brandAccent),
                    SizedBox(width: 7.r),
                    Expanded(
                      child: Text(
                        data.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 10.r,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
