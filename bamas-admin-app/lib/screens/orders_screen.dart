import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/branch_service.dart';
import '../services/session.dart';
import 'admins_screen.dart';
import 'branches_screen.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import 'feedback_screen.dart';
import 'login_screen.dart';
import 'menu_availability_screen.dart';
import 'offers_screen.dart';
import 'order_detail_screen.dart';
import 'backup_screen.dart';
import 'orders_report_screen.dart';
import 'settings_screen.dart';

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
    _loadBranchName();
  }

  /// The branch list is what turns session.branchId into a name in the app
  /// bar. It is fetched once here and cached in BranchService, so the menu
  /// and staff screens reuse it rather than each fetching their own.
  Future<void> _loadBranchName() async {
    try {
      await branchService.list();
      if (mounted) setState(() {});
    } catch (_) {
      // Offline, or an older backend with no /branches route: the app bar
      // just falls back to "Your branch" and nothing else is affected.
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppBranding.appName),
            // Which branch's orders these are. Worth the two lines: a
            // manager who thinks they are looking at every order will sit
            // waiting for one that belongs to another shop.
            Text(
              session.isBranchManager
                  ? (branchService.byId(session.branchId)?.name ?? 'Your branch')
                  : 'All branches',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
            ),
          ],
        ),
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
          PopupMenuButton<Widget>(
            tooltip: 'More',
            onSelected: (screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
            // Hidden entries are not a security control -- the backend
            // refuses these routes for the wrong role regardless. They are
            // hidden so a manager isn't offered buttons that only 403.
            itemBuilder: (context) => [
              const PopupMenuItem(value: OrdersReportScreen(), child: Text('Order reports & download')),
              const PopupMenuItem(value: BranchesScreen(), child: Text('Branches')),
              if (session.canManageStaff)
                const PopupMenuItem(value: AdminsScreen(), child: Text('Staff logins')),
              if (session.seesAllBranches) ...[
                const PopupMenuItem(value: OffersScreen(), child: Text('Offers')),
                const PopupMenuItem(value: SettingsScreen(), child: Text('Settings')),
                const PopupMenuItem(value: BackupScreen(), child: Text('Data backup')),
              ],
              const PopupMenuItem(value: FeedbackScreen(), child: Text('Feedback')),
            ],
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
