import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_config.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In demo mode we skip Firebase entirely so the app runs with fake orders
  // before any backend/Firebase setup has been done. Flip kDemoMode to
  // false in lib/app_config.dart once bamas-admin-backend is running and
  // `flutterfire configure` has been run for this app (see README.md).
  // Which account was last used on this phone, and therefore which screens
  // to draw and which push topic to listen on.
  await session.restore();

  if (!kDemoMode) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.init();
    // Re-assert the topic subscription on every launch. FCM subscriptions
    // can be dropped (app data cleared, token rotated), and a manager whose
    // phone silently stopped listening would just never hear about orders.
    await NotificationService.applySubscriptions();
  }

  runApp(const BamasAdminApp());
}

class BamasAdminApp extends StatelessWidget {
  const BamasAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBranding.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
