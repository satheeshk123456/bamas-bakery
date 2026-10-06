import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// One image widget for the whole app.
///
/// A photo can come from three places: a bundled asset (demo data, path
/// starts with "assets/"), a `data:image/...;base64,...` URI (legacy
/// images left over from the Firestore era), or an https:// URL -- which
/// today means a short-lived S3 presigned link minted by the backend.
///
/// ---------------------------------------------------------------------
/// WHY THIS FILE CARES SO MUCH ABOUT CACHING
///
/// Two separate bugs used to make every photo reload:
///
/// 1. The backend re-signs an S3 URL roughly every 45 minutes, so the SAME
///    photo arrives as a different URL each time the signature rolls over.
///    CachedNetworkImage keys its disk cache on the URL, so the old copy
///    was orphaned and the image downloaded again -- that was the 2-3
///    second wait on opening the app. Fixed by [_stableCacheKey], which
///    strips the AWS signature so the key is the S3 object itself.
///
/// 2. Photos were decoded at full camera resolution. A 4000x3000 JPEG
///    costs ~48 MB in memory, so a grid of them blew past Flutter's image
///    cache, older ones were evicted, and scrolling back up decoded (and
///    often re-fetched) them from scratch. Fixed by [memCacheWidth], which
///    decodes at the size actually drawn.
/// ---------------------------------------------------------------------
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

  /// A cache key that survives the URL being re-signed.
  ///
  /// Only the AWS query string is dropped, and only when it actually looks
  /// like an S3 signature. Other URLs keep their query intact, because for
  /// a normal CDN `?w=400` and `?w=1200` really are different pictures and
  /// collapsing them would show the wrong one.
  ///
  /// Safe to key on the path alone here because the backend never reuses an
  /// S3 key: every upload is `<folder>/<id>-<random>.<ext>`, so one path is
  /// one immutable photo, for good.
  static String _stableCacheKey(String url) {
    final q = url.indexOf('?');
    if (q == -1) return url;
    final query = url.substring(q + 1);
    final isAwsSigned = query.contains('X-Amz-Signature') || query.contains('X-Amz-Credential');
    return isAwsSigned ? url.substring(0, q) : url;
  }

  // Decoding a multi-hundred-KB base64 string is real CPU work -- caching
  // the decoded bytes (keyed by the source string itself) means a widget
  // rebuild reuses the same Uint8List instance instead of re-decoding
  // every time. Capped so a long scroll through many distinct photos
  // can't grow this unboundedly.
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
    final placeholder = fallback ?? Container(color: const Color(0xFFF1EDEA));

    if (source.isEmpty) return placeholder;

    if (_isAsset) {
      return Image.asset(
        source,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    if (_isDataUri) {
      final bytes = _decoded(source);
      if (bytes == null) return placeholder;
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at the size this widget is actually painted at, not the
        // camera's. Null when the box is unbounded -- then full size is
        // the only correct answer.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final int? decodeWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? (constraints.maxWidth * dpr).round()
            : null;

        return CachedNetworkImage(
          imageUrl: source,
          cacheKey: _stableCacheKey(source),
          fit: fit,
          memCacheWidth: decodeWidth,
          // Keep what lands on disk sane too: nobody needs a 12 MP original
          // to fill a 180 px card, and the phone's storage is the client's.
          maxWidthDiskCache: 1280,
          // Short enough not to feel like a load, long enough not to flicker.
          fadeInDuration: const Duration(milliseconds: 120),
          fadeOutDuration: const Duration(milliseconds: 80),
          placeholder: (_, _) => Container(color: const Color(0xFFF1EDEA)),
          errorWidget: (_, _, _) => placeholder,
        );
      },
    );
  }
}
