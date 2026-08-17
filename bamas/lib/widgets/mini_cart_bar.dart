import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../services/cart_provider.dart';

/// A friendly floating bar that appears at the bottom of a browsing screen
/// the moment there's something in the cart — shows a running item count
/// and total, and one tap jumps straight to the cart. Saves the customer
/// from hunting for the Cart tab while they're still picking items.
///
/// Shows nothing at all when the cart is empty.
class MiniCartBar extends StatelessWidget {
  final VoidCallback onViewCart;
  const MiniCartBar({super.key, required this.onViewCart});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              color: AppBranding.primary,
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onViewCart,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cart.itemCount == 1
                              ? '1 item added'
                              : '${cart.itemCount} items added',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      Text(
                        '₹${cart.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'View Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 13),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
