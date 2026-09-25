import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/category.dart';
import 'app_image.dart';

/// Category tile on the home screen.
///
/// The photo fills the whole tile edge to edge -- it used to be a 60x60
/// thumbnail floating in a white box, which wasted most of the tile and
/// made every category look the same at a glance. The name sits below the
/// picture, outside it, so it stays readable whatever the photo is.
class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 1,
              child: AppImage(
                source: category.imageUrl,
                fit: BoxFit.cover,
                fallback: Container(
                  color: AppBranding.secondary.withValues(alpha: 0.16),
                  child: const Icon(Icons.fastfood_rounded,
                      size: 30, color: AppBranding.secondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppBranding.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
