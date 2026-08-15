import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/order_model.dart';
import '../models/shop_settings.dart';
import '../services/firestore_service.dart';
import '../widgets/app_image.dart';
import 'home_screen.dart';

/// Shows live order status. Once the admin marks the order "accepted",
/// this screen reveals the GPay QR code (uploaded by the admin) and lets
/// the customer choose GPay or Cash on Delivery — matching the flow the
/// client described: submit order -> admin calls to confirm -> accept ->
/// customer pays.
class OrderStatusScreen extends StatelessWidget {
  final String orderId;
  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
            child: const Text('Home'),
          ),
        ],
      ),
      body: StreamBuilder<OrderModel?>(
        stream: firestore.orderStream(orderId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snap.data;
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusTracker(status: order.status),
              const SizedBox(height: 20),
              Text('Order #${order.id.substring(0, 6).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...order.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${it['name']} x${it['quantity']}'),
                        Text('₹${(it['price'] * it['quantity']).toStringAsFixed(0)}'),
                      ],
                    ),
                  )),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              if (order.status == 'pending') _PendingCard(),
              if (order.status == 'rejected') _RejectedCard(),
              if (order.status == 'accepted') _PaymentCard(orderId: orderId, order: order),
              if (order.status == 'completed') _CompletedCard(),
            ],
          );
        },
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  final String status;
  const _StatusTracker({required this.status});

  static const _steps = ['pending', 'accepted', 'completed'];

  @override
  Widget build(BuildContext context) {
    if (status == 'rejected') {
      return Row(
        children: const [
          Icon(Icons.cancel, color: AppBranding.danger),
          SizedBox(width: 8),
          Text('Order could not be confirmed', style: TextStyle(color: AppBranding.danger, fontWeight: FontWeight.bold)),
        ],
      );
    }
    final currentIndex = _steps.indexOf(status).clamp(0, _steps.length - 1);
    const labels = ['Order Placed', 'Confirmed by Shop', 'Completed'];
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = (i ~/ 2) < currentIndex;
          return Expanded(
            child: Container(height: 3, color: passed ? AppBranding.primary : Colors.grey.shade300),
          );
        }
        final stepIndex = i ~/ 2;
        final reached = stepIndex <= currentIndex;
        return Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: reached ? AppBranding.primary : Colors.grey.shade300,
              child: Icon(
                reached ? Icons.check : Icons.circle,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(labels[stepIndex], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
            ),
          ],
        );
      }),
    );
  }
}

class _PendingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBranding.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.phone_in_talk, color: AppBranding.secondary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Thanks! Our team will call you shortly to confirm your order.",
              style: TextStyle(color: AppBranding.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBranding.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "Sorry, we couldn't confirm this order. Please call the shop or try placing a new order.",
        style: TextStyle(color: AppBranding.danger),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBranding.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppBranding.success),
          SizedBox(width: 12),
          Expanded(child: Text('Order complete. Thank you for ordering!')),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final String orderId;
  final OrderModel order;
  const _PaymentCard({required this.orderId, required this.order});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _saving = false;

  Future<void> _choose(String method) async {
    setState(() => _saving = true);
    await FirestoreService().setPaymentMethod(widget.orderId, method);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.order.paymentMethod;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppBranding.success, size: 20),
              SizedBox(width: 8),
              Text('Order confirmed! How would you like to pay?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (method == null) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _choose('gpay'),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Pay via GPay'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _choose('cod'),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Cash on Delivery'),
                  ),
                ),
              ],
            ),
          ] else if (method == 'gpay') ...[
            StreamBuilder<ShopSettings>(
              stream: FirestoreService().shopSettingsStream(),
              builder: (context, snap) {
                final qrUrl = snap.data?.gpayQrUrl ?? '';
                final upiId = snap.data?.upiId ?? '';
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 240,
                        child: AppImage(
                          source: qrUrl,
                          fit: BoxFit.contain,
                          fallback: Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'QR code not uploaded yet — please pay Cash on Delivery, or ask the shop for the UPI ID.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (upiId.isNotEmpty) Text('UPI ID: $upiId', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    const Text(
                      "Scan and pay the exact order total, then show the payment confirmation to our delivery person.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppBranding.textMuted, fontSize: 12.5),
                    ),
                  ],
                );
              },
            ),
          ] else if (method == 'cod') ...[
            const Row(
              children: [
                Icon(Icons.payments_outlined, color: AppBranding.textDark),
                SizedBox(width: 8),
                Expanded(child: Text("You'll pay cash when your order arrives.")),
              ],
            ),
          ],
          const SizedBox(height: 8),
          StreamBuilder<ShopSettings>(
            stream: FirestoreService().shopSettingsStream(),
            builder: (context, snap) {
              final shopPhone = snap.data?.contactPhone ?? '';
              if (shopPhone.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () async {
                  final uri = Uri(
                    scheme: 'tel',
                    path: shopPhone.replaceAll(RegExp(r'[^0-9+]'), ''),
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.call, size: 16),
                label: const Text('Need help? Call the shop'),
              );
            },
          ),
        ],
      ),
    );
  }
}
