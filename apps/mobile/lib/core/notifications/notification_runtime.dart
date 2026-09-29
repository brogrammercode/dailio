import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../firebase_options.dart';
import '../router/route_names.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationRuntime {
  NotificationRuntime._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static GoRouter? _router;
  static Map<String, dynamic>? _pendingTap;
  static String? _latestToken;
  static Future<void> Function(String token)? _tokenSync;
  static Future<void> Function()? _inboxRefresh;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      const android = AndroidInitializationSettings('launcher_icon');
      const ios = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          _handleTap(_decode(payload));
        },
      );

      const channel = AndroidNotificationChannel(
        'dailio_general',
        'Dailio notifications',
        description: 'Operational notifications from Dailio',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _messaging.onTokenRefresh.listen((token) {
        _latestToken = token;
        final sync = _tokenSync;
        if (sync != null) sync(token).catchError((_) {});
      });
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleTap(message.data);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _pendingTap = initialMessage.data;
      _latestToken = await _messaging.getToken();
    } catch (error) {
      debugPrint('[Dailio.NOTIFICATIONS] initialization skipped: $error');
    }
  }

  static void setRouter(GoRouter router) {
    _router = router;
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) _handleTap(pending);
  }

  static void setTokenSync(Future<void> Function(String token) sync) {
    _tokenSync = sync;
    final token = _latestToken;
    if (token != null) sync(token).catchError((_) {});
  }

  static void clearTokenSync() {
    _tokenSync = null;
  }

  static void setInboxRefresh(Future<void> Function()? refresh) {
    _inboxRefresh = refresh;
  }

  static Future<String?> getToken() async {
    if (_latestToken != null) return _latestToken;
    try {
      _latestToken = await _messaging.getToken();
    } catch (_) {
      return null;
    }
    return _latestToken;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    await _inboxRefresh?.call();
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title ?? 'Dailio',
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dailio_general',
          'Dailio notifications',
          channelDescription: 'Operational notifications from Dailio',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Map<String, dynamic> _decode(String payload) {
    try {
      final value = jsonDecode(payload);
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    } catch (_) {
      return const {};
    }
  }

  static void _handleTap(Map<String, dynamic> data) {
    final router = _router;
    if (router == null) {
      _pendingTap = data;
      return;
    }
    final route = data['route']?.toString();
    const allowedRoutes = <String>{
      AppRoutes.notifications,
      AppRoutes.home,
      AppRoutes.attendance,
      AppRoutes.fees,
      AppRoutes.joinRequests,
      AppRoutes.roles,
      AppRoutes.shiftManagement,
      AppRoutes.members,
    };
    final feesPrefix = '${AppRoutes.fees}/';
    final attendancePrefix = '${AppRoutes.attendance}/';
    final isAllowed = route != null &&
        (allowedRoutes.contains(route) ||
            route.startsWith(feesPrefix) ||
            route.startsWith(attendancePrefix) ||
            route.startsWith('${AppRoutes.members}/') ||
            route.startsWith(AppRoutes.memberDetail.split(':').first));
    final safeRoute = isAllowed ? route : AppRoutes.notifications;
    router.go(safeRoute);
  }
}
