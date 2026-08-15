import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // White background, because the logo artwork is designed on white.
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
                // If the asset is missing for any reason, fall back to the
                // shop name rather than showing a broken-image box.
                errorBuilder: (_, __, ___) => Text(
                  AppBranding.shopName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppBranding.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (AppBranding.tagline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                AppBranding.tagline,
                style: const TextStyle(color: AppBranding.textMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppBranding.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
