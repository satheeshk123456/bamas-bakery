import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_config.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In demo mode we skip Firebase entirely so the app runs with fake orders
  // before any backend/Firebase setup has been done. Flip kDemoMode to
  // false in lib/app_config.dart once bamas-admin-backend is running and
  // `flutterfire configure` has been run for this app (see README.md).
  if (!kDemoMode) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Subscribing to the "admin_orders" topic doesn't require the admin to
    // be logged in, so this happens once at startup rather than after login.
    await NotificationService.init();
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
