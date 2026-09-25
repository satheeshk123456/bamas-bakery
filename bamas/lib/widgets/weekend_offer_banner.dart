import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'app_image.dart';

/// The weekend offer, drawn as a COUPON.
///
/// This used to be an orange gradient bar with a photo on the end, which
/// from across the room looked like just another one of the offer banners
/// in the carousel above it -- two different things wearing the same
/// clothes. It is now a ticket: pale card, notched edges, a dashed tear
/// line, a coloured stub down the left. Nothing else in the app has that
/// shape, so it reads as "a voucher" at a glance instead of "another ad".
///
/// Still entirely admin-driven: the switch, the message and the optional
/// photo all come from the admin app's Settings screen.
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

    // The notches are drawn in the page's own background colour so they
    // look punched out of the card rather than painted on it.
    final pageColour = Theme.of(context).scaffoldBackgroundColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppBranding.secondary.withValues(alpha: 0.45)),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- the coupon stub ----
                  Container(
                    width: 44,
                    color: AppBranding.secondary,
                    child: const Center(
                      child: Icon(Icons.confirmation_number_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),

                  // ---- the tear line ----
                  const _DashedLine(),

                  // ---- the message ----
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'WEEKEND SPECIAL',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                              color: AppBranding.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: const TextStyle(
                              color: AppBranding.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 62,
                          height: 62,
                          child: AppImage(source: imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ---- punched notches, top and bottom of the tear line ----
          Positioned(left: 44 - 7, top: -7, child: _Notch(colour: pageColour)),
          Positioned(left: 44 - 7, bottom: -7, child: _Notch(colour: pageColour)),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  final Color colour;
  const _Notch({required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
    );
  }
}

/// A vertical dashed rule -- the bit that makes it read as "tear here".
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: CustomPaint(
        painter: _DashedLinePainter(
          colour: AppBranding.secondary.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color colour;
  const _DashedLinePainter({required this.colour});

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, (y + dash).clamp(0, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.colour != colour;
}
