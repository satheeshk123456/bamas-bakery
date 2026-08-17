import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/category.dart';
import 'app_image.dart';

/// The "box type main category" tiles from the client's reference design.
class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: AppImage(
                  source: category.imageUrl,
                  fallback: Container(
                    color: AppBranding.secondary.withValues(alpha: 0.15),
                    child: const Icon(Icons.fastfood,
                        color: AppBranding.secondary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
