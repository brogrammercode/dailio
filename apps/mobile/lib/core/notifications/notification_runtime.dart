import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../firebase_options.dart';
import '../router/route_names.dart';
import '../widgets/dailio_notification_button.dart';

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
  static Future<void>? _initializationFuture;
  static bool _firebaseReady = false;
  static bool _localReady = false;
  static bool _listenersRegistered = false;

  static Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  static Future<void> _initialize() async {
    if (!await _initializeFirebase()) return;

    try {
      await _initializeLocalNotifications();
    } catch (error) {
      debugPrint(
          '[Dailio.NOTIFICATIONS] local notifications unavailable: $error');
      // FCM can still deliver system notifications when local notification
      // setup fails, so continue with Firebase Messaging below.
    }

    try {
      await _requestPermission();
    } catch (error) {
      debugPrint('[Dailio.NOTIFICATIONS] permission request failed: $error');
    }

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint(
          '[Dailio.NOTIFICATIONS] foreground presentation unavailable: $error');
    }

    _registerListeners();

    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleTap(initialMessage.data);
    } catch (error) {
      debugPrint('[Dailio.NOTIFICATIONS] initial message unavailable: $error');
    }

    await _loadAndSyncToken();
    debugPrint('[Dailio.NOTIFICATIONS] runtime ready');
  }

  static Future<bool> _initializeFirebase() async {
    if (_firebaseReady) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      _firebaseReady = true;
      debugPrint('[Dailio.NOTIFICATIONS] Firebase Messaging ready');
      return true;
    } catch (error) {
      debugPrint(
          '[Dailio.NOTIFICATIONS] Firebase initialization failed: $error');
      return false;
    }
  }

  static Future<void> _initializeLocalNotifications() async {
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
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    _localReady = true;
  }

  static Future<void> _requestPermission() async {
    // flutter_local_notifications explicitly requests POST_NOTIFICATIONS on
    // Android 13+. Firebase's requestPermission covers iOS and also returns
    // the final Android authorization state. Keeping both calls makes the
    // behavior reliable across Android plugin versions and fresh installs.
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[Dailio.NOTIFICATIONS] authorization: ${settings.authorizationStatus.name}',
    );
  }

  static void _registerListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;
    _messaging.onTokenRefresh.listen((token) {
      _latestToken = token;
      _syncToken(token);
    });
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message.data);
    });
  }

  static Future<void> _loadAndSyncToken() async {
    try {
      _latestToken = await _messaging.getToken();
      if (_latestToken != null) {
        debugPrint(
          '[Dailio.NOTIFICATIONS] FCM token available (${_latestToken!.length} chars)',
        );
        _syncToken(_latestToken!);
      } else {
        debugPrint('[Dailio.NOTIFICATIONS] FCM token is not available yet');
      }
    } catch (error) {
      debugPrint('[Dailio.NOTIFICATIONS] FCM token unavailable: $error');
    }
  }

  static void _syncToken(String token) {
    final sync = _tokenSync;
    if (sync == null) return;
    sync(token).catchError((error) {
      debugPrint('[Dailio.NOTIFICATIONS] token sync failed: $error');
    });
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
    if (token != null) {
      sync(token).catchError((error) {
        debugPrint('[Dailio.NOTIFICATIONS] token sync failed: $error');
      });
    }
  }

  static void clearTokenSync() {
    _tokenSync = null;
    NotificationBadgeController.clear();
  }

  static void setInboxRefresh(Future<void> Function()? refresh) {
    _inboxRefresh = refresh;
  }

  static Future<String?> getToken() async {
    if (_latestToken != null) return _latestToken;
    if (!_firebaseReady && !await _initializeFirebase()) return null;
    try {
      _latestToken = await _messaging.getToken();
      if (_latestToken != null) {
        debugPrint(
            '[Dailio.NOTIFICATIONS] FCM token available (${_latestToken!.length} chars)');
      }
    } catch (error) {
      debugPrint('[Dailio.NOTIFICATIONS] FCM token unavailable: $error');
      return null;
    }
    return _latestToken;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    NotificationBadgeController.increment();
    await _inboxRefresh?.call();
    final notification = message.notification;
    if (notification == null || !_localReady) return;
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
      AppRoutes.announcements,
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
    final announcementsPrefix = '${AppRoutes.announcements}/';
    final isAllowed = route != null &&
        (allowedRoutes.contains(route) ||
            route.startsWith(feesPrefix) ||
            route.startsWith(attendancePrefix) ||
            route.startsWith(announcementsPrefix) ||
            route.startsWith('${AppRoutes.members}/') ||
            route.startsWith(AppRoutes.memberDetail.split(':').first));
    final safeRoute = isAllowed ? route : AppRoutes.notifications;
    router.go(safeRoute);
  }
}
