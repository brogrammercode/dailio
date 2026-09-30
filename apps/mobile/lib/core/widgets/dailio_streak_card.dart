import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';

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
          return _card(context, current: '-', best: '-', loading: true);
        }
        if (snapshot.hasError || snapshot.data == null) {
          // Keep the surface stable when a background refresh is unavailable.
          // A transient API/cache error must not make the settings card flash
          // and disappear from the page.
          return _card(
            context,
            current: '-',
            best: '-',
            subtitle: 'Unable to refresh right now',
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF171B20) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? const Color(0xFF2A3038) : const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF0F2),
                borderRadius: BorderRadius.circular(12)),
            child: Image.network(dailioStreakFireUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Iconsax.flash_1,
                    color: Colors.redAccent, size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Attendance streak',
                    style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    subtitle ??
                        (loading
                            ? 'Calculating consistency...'
                            : 'Keep showing up consistently'),
                    style: TextStyle(color: muted, fontSize: 11)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$current days',
                style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            Text('best $best', style: TextStyle(color: muted, fontSize: 10)),
          ]),
        ],
      ),
    );
  }
}
