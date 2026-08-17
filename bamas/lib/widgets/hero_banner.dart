import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/review.dart';
import '../models/shop_settings.dart';
import 'app_image.dart';

/// The dark gradient hero section on the home screen: a time-based
/// greeting chip, headline, the shop photo, and the shop name + tagline.
/// Photo, headline and tagline are all editable from the admin panel, so
/// the client can restyle this without a rebuild.
class HeroBanner extends StatelessWidget {
  final ShopSettings? settings;
  final List<Review> reviews;

  const HeroBanner({super.key, required this.settings, required this.reviews});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final shopName = settings?.shopName ?? AppBranding.shopName;
    final headline = settings?.heroHeadline ?? 'Your Burger Cravings, Sorted';
    final tagline = settings?.heroTagline ?? 'Taste the Love, Feel the Quality';
    final imageUrl = settings?.heroImageUrl ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0F0A), Color(0xFF6B1B10), Color(0xFF8E2415)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_sunny_rounded,
                    size: 15, color: AppBranding.secondary),
                const SizedBox(width: 7),
                Text(
                  _greeting(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),

          // Shop photo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.04,
              child: Container(
                color: Colors.black,
                child: AppImage(
                  source: imageUrl,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: Colors.white.withValues(alpha: 0.08),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront,
                            size: 44,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'Add a shop photo from\nthe admin panel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            shopName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: AppBranding.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
