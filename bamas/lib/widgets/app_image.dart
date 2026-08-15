import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// One image widget for the whole app.
///
/// Menu photos can come from two places: a bundled asset (used by the demo
/// data, path starts with "assets/") or a Firebase Storage URL uploaded by
/// the admin. This picks the right loader so screens don't have to care —
/// which means switching from demo data to real data needs no UI changes.
class AppImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final Widget? fallback;

  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  bool get _isAsset => source.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ?? Container(color: Colors.grey.shade200);

    if (source.isEmpty) return placeholder;

    if (_isAsset) {
      return Image.asset(
        source,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      placeholder: (_, __) => Container(color: Colors.grey.shade200),
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}
