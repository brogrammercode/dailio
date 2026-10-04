import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

InputDecoration dailioOnboardingInput(
  String hint,
  IconData icon, {
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.r),
    borderSide: const BorderSide(color: Color(0xFFE4E4E4)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13.r, color: Color(0xFF929292)),
    prefixIcon: Icon(icon, size: 17.r, color: const Color(0xFF929292)),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 13.r),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: BorderSide(color: AppColors.brandAccent, width: 1.4.r),
    ),
  );
}

class DailioOnboardingSectionLabel extends StatelessWidget {
  final String text;

  const DailioOnboardingSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.r),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.brandDark,
          fontSize: 12.r,
          fontWeight: FontWeight.w800,
          letterSpacing: .2.r,
        ),
      ),
    );
  }
}

class DailioOnboardingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool outlined;

  const DailioOnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 18.r,
            height: 18.r,
            child: CircularProgressIndicator(strokeWidth: 2.r),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17.r),
                SizedBox(width: 8.r),
              ],
              Text(label),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: 46.r,
      child: outlined
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandDark,
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: loading ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
              ),
              child: child,
            ),
    );
  }
}

class DailioOnboardingChoiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const DailioOnboardingChoiceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 13.r),
          child: Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E6),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 20.r, color: AppColors.brandAccent),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14.r, fontWeight: FontWeight.w700)),
                    SizedBox(height: 3.r),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.r, color: Color(0xFF858585))),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, size: 17.r, color: Color(0xFF9A9A9A)),
            ],
          ),
        ),
      ),
    );
  }
}

class DailioOnboardingInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const DailioOnboardingInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 11.r),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: const Color(0xFFFFF1E6),
                child: Icon(icon, size: 19.r, color: AppColors.brandAccent),
              ),
              SizedBox(width: 11.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.r, fontWeight: FontWeight.w700)),
                    SizedBox(height: 3.r),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.r, color: Color(0xFF858585))),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class DailioOnboardingEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const DailioOnboardingEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34.r, color: const Color(0xFFB0B0B0)),
            SizedBox(height: 10.r),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.r, fontWeight: FontWeight.w800)),
            SizedBox(height: 4.r),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.r, color: Color(0xFF858585))),
            if (action != null) ...[SizedBox(height: 16.r), action!],
          ],
        ),
      ),
    );
  }
}
