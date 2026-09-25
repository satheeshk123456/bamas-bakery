import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';
import 'session.dart';

/// Admin side of push notifications: this app is Android-only, so unlike
/// the customer app there's no need for a web stub.
///
/// It subscribes to the FCM topic "admin_orders" — the SAME topic the
/// existing Cloud Function (bamas/functions/index.js -> onOrderCreated)
/// already publishes to every time a customer places a new order. No new
/// server-side notification logic is needed for this to work; the backend
/// (bamas-admin-backend) only re-sends it manually via
/// POST /orders/{id}/notify-test for testing.
class NotificationService {
  /// Every branch's orders. The owner and the developer stay on this one.
  static const String adminTopic = 'admin_orders';

  /// One branch's orders. Matches the topic the backend publishes to in
  /// app/routers/orders.py -- change one and you must change the other.
  static String branchTopic(String branchId) => 'branch_${branchId}_managers';

  /// Which topics this phone is currently subscribed to. Kept on disk
  /// because FCM gives no way to ask "what am I subscribed to?", and a
  /// manager who moves branch would otherwise keep receiving the old
  /// branch's orders forever.
  static const String _kTopics = 'bamas_admin_topics';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// Called from a screen (e.g. after login) with a callback to run when a
  /// notification about a specific order should open that order's detail
  /// screen.
  static void Function(String orderId)? onOrderNotificationTapped;

  static Future<void> init() async {
    if (kDemoMode) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // Topics are NOT subscribed here any more. Which ones this phone wants
    // depends on who is logged in, so that happens in applySubscriptions()
    // after the session is restored (main.dart) or after a login.

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final orderId = response.payload;
        if (orderId != null && orderId.isNotEmpty) {
          onOrderNotificationTapped?.call(orderId);
        }
      },
    );

    // Foreground: show a local notification (FCM doesn't auto-show one
    // while the app is open).
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'admin_orders_channel',
            'New Orders',
            channelDescription: 'Alerts the shop when a new order comes in',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
        payload: message.data['orderId'],
      );
    });

    // Tapped while app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final orderId = message.data['orderId'];
      if (orderId != null) onOrderNotificationTapped?.call(orderId);
    });
  }

  /// Subscribes this phone to exactly the topics its signed-in account
  /// should hear, and unsubscribes from anything left over.
  static Future<void> applySubscriptions() async {
    if (kDemoMode) return;

    final wanted = <String>{};
    if (session.seesAllBranches) {
      // Owner / developer: every order, from every branch.
      wanted.add(adminTopic);
    } else if (session.isBranchManager && (session.branchId ?? '').isNotEmpty) {
      // Manager: their branch only -- deliberately NOT admin_orders, or
      // they would be woken by every other branch's orders all night.
      wanted.add(branchTopic(session.branchId!));
    }

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getStringList(_kTopics)?.toSet() ?? <String>{};

    for (final topic in previous.difference(wanted)) {
      try {
        await _messaging.unsubscribeFromTopic(topic);
      } catch (_) {
        // Offline: the stored list is rewritten below either way, and the
        // next successful apply will clean it up.
      }
    }
    for (final topic in wanted.difference(previous)) {
      try {
        await _messaging.subscribeToTopic(topic);
      } catch (_) {
        // Same: a failed subscribe is retried on the next login/launch.
      }
    }
    await prefs.setStringList(_kTopics, wanted.toList());
  }

  /// Called on logout so the phone goes quiet.
  static Future<void> clearSubscriptions() async {
    if (kDemoMode) return;
    final prefs = await SharedPreferences.getInstance();
    for (final topic in prefs.getStringList(_kTopics) ?? const <String>[]) {
      try {
        await _messaging.unsubscribeFromTopic(topic);
      } catch (_) {}
    }
    await prefs.remove(_kTopics);
  }
}
