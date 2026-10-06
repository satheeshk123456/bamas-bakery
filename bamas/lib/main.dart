import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/cart_provider.dart';
import 'services/auth_service.dart';
import 'services/branch_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter's default decoded-image cache is 100 MB / 1000 entries. Menu
  // photos are the bulk of this app, and once the cache overflows the
  // oldest images are thrown away -- which is why scrolling down a long
  // menu and back up made the top images reload. AppImage now decodes at
  // the size actually drawn, so entries are small; raising the ceiling on
  // top of that keeps a whole menu resident for the session.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB
  PaintingBinding.instance.imageCache.maximumSize = 400;

  // In demo mode we skip Firebase entirely so the app runs with fake data
  // before any setup has been done. Flip kDemoMode to false in
  // lib/app_config.dart once `flutterfire configure` has been run.
  if (!kDemoMode) {
    // Firebase is initialised for FCM push notifications only -- identity
    // and all data now come from bamas-admin-backend.
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.init();
  }

  // Reload any session saved on this device before the first frame, so a
  // returning customer isn't flashed the login screen on every launch.
  await AuthService.instance.restoreSession();

  // And the branch this phone last ordered from, so a returning customer
  // lands on the menu instead of being asked to pick a branch every launch.
  await BranchService.instance.restore();

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
