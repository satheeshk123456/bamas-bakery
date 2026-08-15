import 'package:flutter/material.dart';

/// Central place for all branding. Colors below are sampled from the
/// client's logo (BBB_JEPG_White_Bg.jpg).
class AppBranding {
  static const String shopName = "Bama's Burger Box";

  /// Optional strapline shown under the logo on the splash screen.
  /// Left empty on purpose — the client hasn't supplied one, and the logo
  /// already carries the name. Put text here if they want one.
  static const String tagline = '';

  /// Path to the logo. Replace assets/images/logo.png with the client's
  /// file and everything below picks it up automatically.
  static const String logoAsset = 'assets/images/logo.png';

  // --- Palette sampled from the logo ---
  static const Color primary = Color(0xFFE8341C); // logo red
  static const Color secondary = Color(0xFFF7A023); // burger/drink orange
  static const Color outline = Color(0xFF1A1A1A); // logo's black outline
  static const Color background = Color(0xFFFFF9F5); // soft warm white
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF241C1C);
  static const Color textMuted = Color(0xFF7A6F6F);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
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
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppBranding.primary,
        unselectedItemColor: AppBranding.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}
