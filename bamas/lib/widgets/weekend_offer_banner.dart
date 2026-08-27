import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'app_image.dart';

/// Weekend offer banner shown on the home screen. Entirely admin-driven —
/// only rendered when the admin has switched the offer on from the admin
/// panel, and shows whatever message (and optional photo) they typed
/// there. Nothing here needs an app update to change.
class WeekendOfferBanner extends StatelessWidget {
  final String text;
  final String imageUrl;

  const WeekendOfferBanner({
    super.key,
    required this.text,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppBranding.secondary, Color(0xFFFFC862)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppBranding.secondary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration_rounded,
                        color: AppBranding.outline, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppBranding.outline,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
              child: SizedBox(
                width: 78,
                height: 78,
                child: AppImage(source: imageUrl, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}
