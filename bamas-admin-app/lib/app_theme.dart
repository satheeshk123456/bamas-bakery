import 'package:flutter/material.dart';

/// Central place for all branding — same palette as the customer app
/// (bamas/lib/app_theme.dart), sampled from the shop logo, so the two apps
/// feel like one product even though they're separate installs.
class AppBranding {
  static const String appName = 'Bamas Admin';
  static const String tagline = 'Order management';

  /// Same logo file as the customer app.
  static const String logoAsset = 'assets/images/logo.png';

  // --- Palette sampled from the logo (kept identical to the customer app) ---
  static const Color primary = Color(0xFFE8341C); // logo red
  static const Color secondary = Color(0xFFF7A023); // burger/drink orange
  static const Color outline = Color(0xFF1A1A1A);
  static const Color background = Color(0xFFFFF9F5);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF241C1C);
  static const Color textMuted = Color(0xFF7A6F6F);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
  static const Color warning = Color(0xFFB07B00);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppBranding.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppBranding.primary,
        primary: AppBranding.primary,
        secondary: AppBranding.secondary,
        surface: AppBranding.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppBranding.background,
        foregroundColor: AppBranding.textDark,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: AppBranding.textDark),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: AppBranding.textDark),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppBranding.textDark),
        bodyMedium: TextStyle(color: AppBranding.textDark),
        bodySmall: TextStyle(color: AppBranding.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppBranding.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBranding.primary,
          side: const BorderSide(color: AppBranding.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
