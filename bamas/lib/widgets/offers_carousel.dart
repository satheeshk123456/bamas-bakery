import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/offer.dart';
import '../screens/full_image_screen.dart';
import 'app_image.dart';

/// Home-page promo banners -- the big, photo-led ones.
///
/// Deliberately the opposite shape to the weekend coupon below it: this is
/// a full-bleed photograph with the text laid over it, that one is a pale
/// notched ticket. Two different promotions should not look like the same
/// component twice.
///
/// Fully admin-controlled (the admin app's Offers screen): nothing renders
/// when there are no active offers, a single banner when there is one, and
/// an auto-advancing carousel with dots when there is more than one.
class OffersCarousel extends StatefulWidget {
  final List<OfferModel> offers;
  const OffersCarousel({super.key, required this.offers});

  @override
  State<OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<OffersCarousel> {
  // viewportFraction < 1 lets the next banner peek in at the edge, which
  // is what tells people there is more than one without reading the dots.
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  List<OfferModel> get _active =>
      widget.offers.where((o) => o.isActive && o.imageUrl.isNotEmpty).toList();

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
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
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
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _controller,
              itemCount: offers.length,
              padEnds: true,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _OfferBanner(offer: offers[i]),
            ),
          ),
          if (offers.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                offers.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppBranding.primary : Colors.black.withValues(alpha: 0.13),
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

class _OfferBanner extends StatelessWidget {
  final OfferModel offer;
  const _OfferBanner({required this.offer});

  @override
  Widget build(BuildContext context) {
    final hasText = offer.title.isNotEmpty || offer.subtitle.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FullImageScreen(source: offer.imageUrl)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(source: offer.imageUrl, fit: BoxFit.cover),

              // A deeper scrim than before, and only at the bottom third,
              // so white text stays readable over a bright food photo
              // without dulling the whole picture.
              if (hasText)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0.0, 0.62],
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                ),

              Positioned(
                left: 14,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppBranding.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'OFFER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ),

              if (hasText)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (offer.title.isNotEmpty)
                        Text(
                          offer.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            height: 1.15,
                          ),
                        ),
                      if (offer.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          offer.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
