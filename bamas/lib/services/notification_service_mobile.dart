import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app_config.dart';

/// Handles the customer side of push notifications: getting an FCM token
/// (stored on the order so Cloud Functions can notify this exact device
/// when the admin accepts/rejects the order) and showing a local
/// notification when a message arrives while the app is open.
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kDemoMode) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'orders_channel',
            'Order Updates',
            channelDescription: 'Updates about your Bamas Burger order',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  static Future<String?> getToken() async {
    if (kDemoMode) return null;
    try {
      return await _messaging.getToken();
    } catch (_) {
      // Token can fail on emulators without Play Services / before
      // Firebase is fully configured — order placement should not block
      // on this, so we just fall back to no push notifications.
      return null;
    }
  }
}
