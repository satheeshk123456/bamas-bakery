import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/order.dart';
import '../services/order_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Order> _future;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _future = orderService.getOrder(widget.orderId);
  }

  Future<void> _setStatus(String status) async {
    setState(() => _updating = true);
    try {
      await orderService.updateStatus(widget.orderId, status);
      if (!mounted) return;
      setState(() => _future = orderService.getOrder(widget.orderId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order marked as $status. The customer is notified automatically.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: FutureBuilder<Order>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Could not load order.\n${snapshot.error ?? ''}'));
          }
          final order = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(order.customerName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(order.customerPhone, style: const TextStyle(color: AppBranding.textMuted)),
              if (order.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(order.address, style: const TextStyle(color: AppBranding.textMuted)),
              ],
              const SizedBox(height: 20),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...order.items.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('${i.quantity} × '),
                        Expanded(child: Text(i.name)),
                        Text('₹${(i.price * i.quantity).toStringAsFixed(0)}'),
                      ],
                    ),
                  )),
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (order.paymentMethod != null) ...[
                const SizedBox(height: 6),
                Text('Payment: ${order.paymentMethod}', style: const TextStyle(color: AppBranding.textMuted)),
              ],
              const SizedBox(height: 32),
              if (order.status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _updating ? null : () => _setStatus('rejected'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppBranding.danger, side: const BorderSide(color: AppBranding.danger)),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _updating ? null : () => _setStatus('accepted'),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              if (order.status == 'accepted')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updating ? null : () => _setStatus('completed'),
                    child: const Text('Mark completed'),
                  ),
                ),
              if (order.status == 'completed' || order.status == 'rejected')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('This order is ${order.status}.', style: const TextStyle(color: AppBranding.textMuted)),
                ),
            ],
          );
        },
      ),
    );
  }
}
