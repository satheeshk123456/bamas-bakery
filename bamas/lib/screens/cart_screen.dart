import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../services/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final bool embedded; // true when shown as a bottom-nav tab (no back button needed)
  const CartScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items.values.toList();

    final body = items.isEmpty
        ? const _EmptyCart()
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, i) {
                    final ci = items[i];
                    return Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppBranding.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lunch_dining, color: AppBranding.secondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ci.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('₹${ci.item.price.toStringAsFixed(0)} x ${ci.quantity}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => context.read<CartProvider>().removeOne(ci.item.id),
                            ),
                            Text('${ci.quantity}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => context.read<CartProvider>().addItem(ci.item),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              _CheckoutBar(total: cart.totalAmount),
            ],
          );

    if (embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Your Cart', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: body,
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Your cart is empty'),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final double total;
  const _CheckoutBar({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.bodySmall),
                  Text('₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              ),
              child: const Text('Proceed to Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
