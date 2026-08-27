import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/auth_service.dart';
import 'order_status_screen.dart';

/// Shows the signed-in account's own orders, fetched from the backend
/// (GET /account/orders — bamas-admin-backend, filtered to the caller's
/// uid) rather than a live Firestore stream. Pull down to refresh.
class OrderHistoryScreen extends StatefulWidget {
  final bool embedded;
  const OrderHistoryScreen({super.key, this.embedded = false});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<OrderModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.instance.fetchMyOrders();
  }

  Future<void> _refresh() async {
    final future = AuthService.instance.fetchMyOrders();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<OrderModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Center(child: Text('Could not load your orders. Pull down to retry.')),
              ],
            );
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Center(child: Text('No orders yet')),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final order = orders[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Order #${order.id.substring(0, 6).toUpperCase()}'),
                  subtitle: Text(
                    'Status: ${order.status} • ₹${order.totalAmount.toStringAsFixed(0)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: order.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('My Orders', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: body,
    );
  }
}
