import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// One image widget for the whole app.
///
/// A photo can come from three places: a bundled asset (demo data, path
/// starts with "assets/"), a `data:image/...;base64,...` URI (anything
/// the admin uploaded -- menu items, categories, offers, shop photos --
/// stored straight in Firestore instead of Firebase Storage, which now
/// needs the paid Blaze plan just to create a bucket), or a plain
/// https:// URL (the seeded stock photos). This picks the right loader
/// so screens never have to care which one they got.
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
  bool get _isDataUri => source.startsWith('data:');

  // Decoding a multi-hundred-KB base64 string is real CPU work -- caching
  // the decoded bytes (keyed by the source string itself) means a widget
  // rebuild reuses the same Uint8List instance instead of re-decoding
  // every time, and Image.memory's own frame cache keys off that
  // instance staying stable. Capped so a long scroll through many
  // distinct photos can't grow this unboundedly.
  static final Map<String, Uint8List> _decodedCache = {};

  Uint8List? _decoded(String source) {
    final cached = _decodedCache[source];
    if (cached != null) return cached;
    try {
      final commaIndex = source.indexOf(',');
      if (commaIndex == -1) return null;
      final bytes = base64Decode(source.substring(commaIndex + 1));
      if (_decodedCache.length > 80) _decodedCache.clear();
      _decodedCache[source] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

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

    if (_isDataUri) {
      final bytes = _decoded(source);
      if (bytes == null) return placeholder;
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
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
