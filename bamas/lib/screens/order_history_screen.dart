import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';
import 'order_status_screen.dart';

/// Guest checkout means there's no login, so "My Orders" is a locally
/// remembered list of order IDs placed from this device (saved in
/// shared_preferences at checkout time).
class OrderHistoryScreen extends StatefulWidget {
  final bool embedded;
  const OrderHistoryScreen({super.key, this.embedded = false});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _firestore = FirestoreService();
  List<String> _orderIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _orderIds = prefs.getStringList('myOrderIds') ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_orderIds.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No orders yet'),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _orderIds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final id = _orderIds[i];
            return StreamBuilder<OrderModel?>(
              stream: _firestore.orderStream(id),
              builder: (context, snap) {
                final order = snap.data;
                final status = order?.status ?? '…';
                final total = order?.totalAmount;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Order #${id.substring(0, 6).toUpperCase()}'),
                    subtitle: Text(
                      'Status: $status${total != null ? ' • ₹${total.toStringAsFixed(0)}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: id)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

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
