import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app_config.dart';

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
  static const String adminTopic = 'admin_orders';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// Called from a screen (e.g. after login) with a callback to run when a
  /// notification about a specific order should open that order's detail
  /// screen.
  static void Function(String orderId)? onOrderNotificationTapped;

  static Future<void> init() async {
    if (kDemoMode) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.subscribeToTopic(adminTopic);

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
}
