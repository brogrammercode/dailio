import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shows the shared, printable Dailio QR presentation used for every
/// permanent QR payload (branch, plan, gate, and future QR purposes).
Future<void> showDailioQrSheet(
  BuildContext context, {
  required String title,
  required String payload,
  String? subtitle,
  String? detail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DailioQrSheet(
      title: title,
      payload: payload,
      subtitle: subtitle,
      detail: detail,
    ),
  );
}

class DailioQrSheet extends StatelessWidget {
  final String title;
  final String payload;
  final String? subtitle;
  final String? detail;

  const DailioQrSheet({
    super.key,
    required this.title,
    required this.payload,
    this.subtitle,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 460.r),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            padding: EdgeInsets.fromLTRB(20.r, 10.r, 20.r, 18.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34.r,
                  height: 4.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D6),
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),
                SizedBox(height: 14.r),
                Row(
                  children: [
                    Container(
                      width: 34.r,
                      height: 34.r,
                      decoration: BoxDecoration(
                        color: AppColors.brandAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(Iconsax.scan_barcode,
                          size: 18.r, color: AppColors.brandAccent),
                    ),
                    SizedBox(width: 10.r),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15.r,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandDark)),
                          if (subtitle != null)
                            Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.r, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Iconsax.close_circle,
                          size: 21.r, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints:
                          BoxConstraints(minWidth: 32.r, minHeight: 32.r),
                    ),
                  ],
                ),
                SizedBox(height: 18.r),
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: const Color(0xFFEAEAEA)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: payload,
                        size: 236.r,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.brandDark,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.brandDark,
                        ),
                      ),
                      Container(
                        width: 48.r,
                        height: 48.r,
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFE6E6E6), width: 2.r),
                        ),
                        child: ClipOval(
                          child:
                              Image.asset('assets/logo.png', fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.r),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.verify, size: 15.r, color: Colors.green),
                    SizedBox(width: 5.r),
                    Text('Permanent QR • no expiry',
                        style: TextStyle(
                            fontSize: 11.r,
                            color: Colors.green,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                if (detail != null) ...[
                  SizedBox(height: 4.r),
                  Text(detail!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.r, color: Colors.grey)),
                ],
                SizedBox(height: 14.r),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandDark,
                      padding: EdgeInsets.symmetric(vertical: 12.r),
                      side: const BorderSide(color: Color(0xFFE1E1E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: const Text('Done',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
