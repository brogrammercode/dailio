import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../network/api_client.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';

class NotificationBadgeController {
  NotificationBadgeController._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static Future<void>? _refreshing;

  static Future<void> refresh(ApiClient api) {
    final active = _refreshing;
    if (active != null) return active;
    final request = _load(api);
    _refreshing = request.whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  static Future<void> _load(ApiClient api) async {
    final requestVersion = _version;
    try {
      final response = await api.dio.get('/notifications/unread-count');
      final data = response.data;
      final count = data is Map && data['data'] is Map
          ? (data['data']['count'] as num?)?.toInt() ?? 0
          : 0;
      if (requestVersion == _version) unreadCount.value = count;
    } catch (_) {
      // The icon remains available when the count request is offline.
    }
  }

  static int _version = 0;

  static void setCount(int count) {
    _version++;
    unreadCount.value = count < 0 ? 0 : count;
  }

  static void increment([int amount = 1]) {
    _version++;
    unreadCount.value = (unreadCount.value + amount).clamp(0, 999999);
  }

  static void clear() => setCount(0);
}

class DailioNotificationButton extends StatefulWidget {
  const DailioNotificationButton({super.key});

  @override
  State<DailioNotificationButton> createState() =>
      _DailioNotificationButtonState();
}

class _DailioNotificationButtonState extends State<DailioNotificationButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        NotificationBadgeController.refresh(context.read<ApiClient>());
      } catch (_) {
        // Auth screens and lightweight widget tests may not provide the API yet.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationBadgeController.unreadCount,
      builder: (context, count, _) => IconButton(
        tooltip: 'Notifications',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        onPressed: () => context.push(AppRoutes.notifications),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: AppColors.brandAccent,
          smallSize: 7,
          largeSize: 16,
          textStyle: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
          child: const Icon(Iconsax.notification, size: 20),
        ),
      ),
    );
  }
}
