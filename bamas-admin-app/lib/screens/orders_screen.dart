import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import 'login_screen.dart';
import 'menu_availability_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _statuses = const ['pending', 'accepted', 'completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    // If a push notification is tapped while an order screen is already
    // showing, jump straight to that order.
    NotificationService.onOrderNotificationTapped = (orderId) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
      );
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppBranding.appName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Pending'), Tab(text: 'Accepted'), Tab(text: 'Completed')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fastfood_outlined),
            tooltip: 'Menu: photos, rates & offers',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MenuAvailabilityScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await authService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((s) => _OrderList(status: s)).toList(),
      ),
    );
  }
}

class _OrderList extends StatefulWidget {
  final String status;
  const _OrderList({required this.status});

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = orderService.listOrders(status: widget.status);
  }

  Future<void> _refresh() async {
    setState(() => _future = orderService.listOrders(status: widget.status));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Order>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Could not load orders.\n${snapshot.error}', textAlign: TextAlign.center)),
            ]);
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              Center(child: Text('No orders here yet.', style: TextStyle(color: AppBranding.textMuted))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _OrderCard(order: orders[i], onChanged: _refresh),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onChanged;
  const _OrderCard({required this.order, required this.onChanged});

  Color get _statusColor => switch (order.status) {
        'pending' => AppBranding.warning,
        'accepted' => AppBranding.primary,
        'completed' => AppBranding.success,
        'rejected' => AppBranding.danger,
        _ => AppBranding.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final time = order.createdAt != null
        ? DateFormat('MMM d, h:mm a').format(DateTime.tryParse(order.createdAt!)?.toLocal() ?? DateTime.now())
        : '';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)));
          onChanged();
        },
        title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${order.itemCount} item(s) • ₹${order.totalAmount.toStringAsFixed(0)}${time.isNotEmpty ? ' • $time' : ''}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
          child: Text(order.status, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
