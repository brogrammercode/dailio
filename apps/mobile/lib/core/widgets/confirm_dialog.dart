import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  IconData icon = Iconsax.info_circle,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DailioConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Continue',
  String hintText = 'Enter a reason',
  bool isDestructive = false,
  IconData icon = Iconsax.edit_2,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DailioReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      hintText: hintText,
      isDestructive: isDestructive,
      icon: icon,
    ),
  );
}

class _DailioConfirmDialog extends StatelessWidget {
  const _DailioConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final actionColor = isDestructive ? AppColors.error : AppColors.brandAccent;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.r, vertical: 24.r),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18.r, 18.r, 18.r, 16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Icon(icon, color: actionColor, size: 19.r),
                ),
                SizedBox(width: 11.r),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2.r),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 16.r,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 13.r),
            Text(
              message,
              style: TextStyle(
                color: Color(0xFF6B6B6B),
                fontSize: 12.r,
                height: 1.4,
              ),
            ),
            SizedBox(height: 18.r),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandDark,
                      side: const BorderSide(color: Color(0xFFE3E3E3)),
                      minimumSize: Size.fromHeight(40.r),
                      padding: EdgeInsets.symmetric(horizontal: 10.r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                SizedBox(width: 9.r),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(40.r),
                      padding: EdgeInsets.symmetric(horizontal: 10.r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailioReasonDialog extends StatefulWidget {
  const _DailioReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.hintText,
    required this.isDestructive,
    required this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String hintText;
  final bool isDestructive;
  final IconData icon;

  @override
  State<_DailioReasonDialog> createState() => _DailioReasonDialogState();
}

class _DailioReasonDialogState extends State<_DailioReasonDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = 'This field is required.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final actionColor =
        widget.isDestructive ? AppColors.error : AppColors.brandAccent;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.r, vertical: 24.r),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18.r, 18.r, 18.r, 16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Icon(widget.icon, color: actionColor, size: 19.r),
                ),
                SizedBox(width: 11.r),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 16.r,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.message != null) ...[
              SizedBox(height: 12.r),
              Text(widget.message!,
                  style: TextStyle(
                      color: Color(0xFF6B6B6B), fontSize: 12.r, height: 1.4)),
            ],
            SizedBox(height: 15.r),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.hintText,
                errorText: _errorText,
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.r, vertical: 11.r),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E4))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E4))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: actionColor, width: 1.3.r)),
              ),
            ),
            SizedBox(height: 16.r),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandDark,
                      side: const BorderSide(color: Color(0xFFE3E3E3)),
                      minimumSize: Size.fromHeight(40.r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 9.r),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(40.r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text(widget.confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
