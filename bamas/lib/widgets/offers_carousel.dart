import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/offer.dart';
import '../screens/full_image_screen.dart';
import 'app_image.dart';

/// Home-page promo banners, fully admin-controlled (see the admin app's
/// Offers screen). Shows nothing if there are no active offers, a single
/// static banner if there's exactly one, or an auto-advancing carousel
/// with dot indicators when there's more than one.
class OffersCarousel extends StatefulWidget {
  final List<OfferModel> offers;
  const OffersCarousel({super.key, required this.offers});

  @override
  State<OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<OffersCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  List<OfferModel> get _active => widget.offers.where((o) => o.isActive && o.imageUrl.isNotEmpty).toList();

  @override
  void didUpdateWidget(covariant OffersCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restartAutoPlay();
  }

  @override
  void initState() {
    super.initState();
    _restartAutoPlay();
  }

  void _restartAutoPlay() {
    _timer?.cancel();
    if (_active.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _active.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offers = _active;
    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _controller,
                itemCount: offers.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final offer = offers[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FullImageScreen(source: offer.imageUrl)),
                    ),
                    child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(source: offer.imageUrl, fit: BoxFit.cover),
                      if (offer.title.isNotEmpty || offer.subtitle.isNotEmpty)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                            ),
                          ),
                        ),
                      if (offer.title.isNotEmpty || offer.subtitle.isNotEmpty)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (offer.title.isNotEmpty)
                                Text(
                                  offer.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              if (offer.subtitle.isNotEmpty)
                                Text(
                                  offer.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                ),
                            ],
                          ),
                        ),
                    ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (offers.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                offers.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppBranding.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
