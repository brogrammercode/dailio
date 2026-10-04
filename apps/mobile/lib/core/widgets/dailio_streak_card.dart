import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const dailioStreakFireUrl =
    'https://cdn-icons-png.flaticon.com/128/8835/8835848.png';

class DailioStreakCard extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  final bool dark;

  const DailioStreakCard({super.key, required this.future, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _card(context, current: '0', best: '0', loading: true);
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _card(
            context,
            current: '0',
            best: '0',
            subtitle: 'No attendance streak yet',
          );
        }
        final data = snapshot.data!;
        return _card(
          context,
          current: '${data['current_streak'] ?? 0}',
          best: '${data['best_streak'] ?? 0}',
        );
      },
    );
  }

  Widget _card(BuildContext context,
      {required String current,
      required String best,
      bool loading = false,
      String? subtitle}) {
    final foreground = dark ? Colors.white : AppColors.brandDark;
    final muted = dark ? const Color(0xFFA7ADB5) : const Color(0xFF777777);
    return Container(
      margin: EdgeInsets.only(top: 8.r),
      padding: EdgeInsets.fromLTRB(4.r, 10.r, 4.r, 12.r),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF171B20) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF2A3038) : const Color(0xFFEAEAEA),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF0F2), shape: BoxShape.circle),
            child: Image.network(dailioStreakFireUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Iconsax.flash_1, color: Colors.redAccent, size: 24.r)),
          ),
          SizedBox(width: 12.r),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Attendance streak',
                    style: TextStyle(
                        color: foreground,
                        fontSize: 13.r,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 3.r),
                Text(
                    subtitle ??
                        (loading
                            ? 'Checking attendance'
                            : 'Keep showing up consistently'),
                    style: TextStyle(color: muted, fontSize: 11.r)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$current days',
                style: TextStyle(
                    color: foreground,
                    fontSize: 15.r,
                    fontWeight: FontWeight.w800)),
            Text('best $best', style: TextStyle(color: muted, fontSize: 10.r)),
          ]),
        ],
      ),
    );
  }
}
