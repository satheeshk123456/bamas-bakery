import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/menu_item.dart';
import '../services/cart_provider.dart';
import 'app_image.dart';

/// Food card used on the Home and Category screens.
///
/// Layout: the photo runs edge to edge across the top of the card with
/// nothing inset around it, and every piece of text sits underneath on
/// white. A food photo sells the dish; cropping it into a small inset box
/// with text on top of it does neither job well.
///
/// The rating rides on the photo as a small pill rather than taking a row
/// of its own, which buys the dish name the full width of the card.
class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  const MenuItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.items[item.id]?.quantity ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- photo: full bleed, no padding, no inner radius ----
          Stack(
            children: [
              AspectRatio(
                // Slightly taller than wide: food reads better with a bit
                // of height, and it keeps every card in the grid identical.
                aspectRatio: 1.08,
                child: AppImage(
                  source: item.imageUrl,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: AppBranding.secondary.withValues(alpha: 0.14),
                    child: const Icon(Icons.lunch_dining,
                        size: 42, color: AppBranding.secondary),
                  ),
                ),
              ),

              // Rating pill, floating on the photo.
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB300)),
                      const SizedBox(width: 2),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppBranding.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!item.isAvailable)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SOLD OUT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ---- text, all of it below the photo ----
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 9, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.15,
                    color: AppBranding.textDark,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppBranding.primary,
                      ),
                    ),
                    if (item.isAvailable)
                      _QuantityControl(item: item, quantity: inCart),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  const _QuantityControl({required this.item, required this.quantity});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    if (quantity == 0) {
      return Material(
        color: AppBranding.primary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => cart.addItem(item),
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppBranding.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Step(icon: Icons.remove_rounded, onTap: () => cart.removeOne(item.id)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
          _Step(icon: Icons.add_rounded, onTap: () => cart.addItem(item)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Step({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
