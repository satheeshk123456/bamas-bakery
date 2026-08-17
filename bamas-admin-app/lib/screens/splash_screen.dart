import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'orders_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () async {
      if (!mounted) return;
      final loggedIn = await authService.isLoggedIn;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => loggedIn ? const OrdersScreen() : const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // White background, since the logo artwork is designed on white
    // (same convention as the customer app's splash screen).
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                AppBranding.logoAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  AppBranding.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppBranding.primary, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppBranding.tagline,
              style: const TextStyle(color: AppBranding.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppBranding.primary),
            ),
          ],
        ),
      ),
    );
  }
}
