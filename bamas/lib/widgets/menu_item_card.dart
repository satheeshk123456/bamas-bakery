import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/menu_item.dart';
import '../services/cart_provider.dart';
import 'app_image.dart';

/// Food card used on Home + Category screens. Matches the reference
/// design: image, name, rating, price, and a quick add (+) button.
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: AppImage(
                  source: item.imageUrl,
                  fallback: Container(
                    color: AppBranding.secondary.withValues(alpha: 0.15),
                    child: const Icon(Icons.lunch_dining,
                        size: 40, color: AppBranding.secondary),
                  ),
                ),
              ),
              if (!item.isAvailable)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: const Text(
                      'SOLD OUT',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(item.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₹${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
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
      return InkWell(
        onTap: () => cart.addItem(item),
        borderRadius: BorderRadius.circular(20),
        child: const CircleAvatar(
          radius: 16,
          backgroundColor: AppBranding.primary,
          child: Icon(Icons.add, color: Colors.white, size: 18),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => cart.removeOne(item.id),
          child: const CircleAvatar(
            radius: 13,
            backgroundColor: Color(0xFFEFEFEF),
            child: Icon(Icons.remove, size: 16, color: AppBranding.textDark),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () => cart.addItem(item),
          child: const CircleAvatar(
            radius: 13,
            backgroundColor: AppBranding.primary,
            child: Icon(Icons.add, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
