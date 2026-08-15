import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/cart_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In demo mode we skip Firebase entirely so the app runs with fake data
  // before any setup has been done. Flip kDemoMode to false in
  // lib/app_config.dart once `flutterfire configure` has been run.
  if (!kDemoMode) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.init();
  }

  runApp(const BamasApp());
}

class BamasApp extends StatelessWidget {
  const BamasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp(
        title: AppBranding.shopName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
