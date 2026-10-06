import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/shop_settings.dart';
import '../services/api_service.dart';
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
    // The home screen already shows a "we're closed" banner, but the
    // checkout button sat here fully enabled underneath it -- so the
    // banner's promise that "ordering is paused" simply was not true.
    // This is the app-side half of that; the backend refuses a closed
    // branch's orders outright, which is what actually enforces it for
    // app versions already installed on customers' phones.
    return StreamBuilder<ShopSettings>(
      stream: FirestoreService().shopSettingsStream(),
      builder: (context, snap) {
        // Open until proven otherwise: a slow first response must never
        // stop a customer who is allowed to order. The backend has the
        // final say, so guessing "open" here is safe.
        final isOpen = snap.data?.isOpen ?? true;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOpen)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 17, color: AppBranding.danger),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Closed right now — your cart is saved, order when we reopen.',
                            style: TextStyle(
                              color: AppBranding.danger,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
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
                      onPressed: isOpen
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                              )
                          : null,
                      child: Text(isOpen ? 'Proceed to Checkout' : 'Closed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
