import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cart_provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/order_api_service.dart';
import 'order_status_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  bool _placing = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _prefillFromLastOrder();
  }

  Future<void> _prefillFromLastOrder() async {
    final prefs = await SharedPreferences.getInstance();
    _nameCtrl.text = prefs.getString('customerName') ?? '';
    _phoneCtrl.text = prefs.getString('customerPhone') ?? '';
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Please turn on location services';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }

      final pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;

      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          _addressCtrl.text =
              [p.name, p.street, p.subLocality, p.locality, p.postalCode]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(', ');
        }
      } catch (_) {
        // Reverse geocoding is best-effort; coordinates are still saved.
        _addressCtrl.text = 'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}';
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;

    setState(() => _placing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customerName', _nameCtrl.text.trim());
      await prefs.setString('customerPhone', _phoneCtrl.text.trim());

      final token = await NotificationService.getToken();

      // Captured before placeOrder/clear() so the WhatsApp message below
      // still has the items and total to describe, even after the cart
      // is emptied.
      final orderItems = cart.toOrderItems();
      final orderTotal = cart.totalAmount;

      final orderId = await orderApiService.placeOrder(
        items: orderItems,
        totalAmount: orderTotal,
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        fcmToken: token,
        userId: AuthService.instance.currentUser?.uid,
      );

      cart.clear();

      // Best-effort: hands off to WhatsApp with the order details
      // pre-filled, addressed to the shop's own number, so the customer
      // just has to tap Send. The order is already saved at this point,
      // so if WhatsApp isn't installed or this fails for any reason, the
      // order flow itself is unaffected — this never throws.
      await _notifyShopOnWhatsApp(orderId: orderId, items: orderItems, total: orderTotal);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: orderId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not place order: $e')));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// Opens WhatsApp (via the wa.me deep link — no WhatsApp Business API,
  /// no approval process, works with a plain personal or business
  /// WhatsApp number) addressed to the shop's contact number from
  /// shopSettings, with the new order's details pre-filled as the
  /// message text. The customer's own WhatsApp account sends it, so it
  /// arrives from the customer's number as a normal chat message.
  Future<void> _notifyShopOnWhatsApp({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    try {
      final settings = await FirestoreService().shopSettingsStream().first;
      final shopPhone = settings.contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (shopPhone.isEmpty) return; // shop hasn't set a contact number yet

      final message = StringBuffer()
        ..writeln('New order from ${_nameCtrl.text.trim()} (${_phoneCtrl.text.trim()})')
        ..writeln('Address: ${_addressCtrl.text.trim()}')
        ..writeln()
        ..writeln('Items:');
      for (final it in items) {
        final qty = it['quantity'] as int;
        final price = (it['price'] as num).toDouble();
        message.writeln('$qty x ${it['name']} - ₹${(price * qty).toStringAsFixed(0)}');
      }
      message
        ..writeln()
        ..writeln('Total: ₹${total.toStringAsFixed(0)}')
        ..writeln('Order ID: ${orderId.substring(0, 6).toUpperCase()}');

      final uri = Uri.parse(
        'https://wa.me/$shopPhone?text=${Uri.encodeComponent(message.toString())}',
      );
      // Calling launchUrl directly (no canLaunchUrl gate) -- an https://
      // link can always be opened by *something* (WhatsApp if installed,
      // otherwise a browser that redirects into WhatsApp Web/the Play
      // Store), and canLaunchUrl can incorrectly report false on Android
      // 11+ if the manifest's <queries> block is ever out of date, which
      // would silently skip this with no visible symptom.
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('checkout: launchUrl returned false for $uri');
      }
    } catch (e) {
      // Never let a WhatsApp hiccup block order placement -- the order
      // itself is already saved in Firestore by the time this runs. Still
      // logged so a real failure (bad number format, etc.) is visible in
      // `flutter run` output instead of silently vanishing.
      debugPrint('checkout: could not open WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text('Delivery location', style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('Use current'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address / landmark'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a delivery address' : null,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items'),
                      Text('${cart.itemCount}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${cart.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Payment is arranged after our team calls to confirm your order — you'll pay online via UPI, card, or QR code.",
              style: TextStyle(color: AppBranding.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _placing ? null : _placeOrder,
              child: _placing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Order'),
            ),
          ],
        ),
      ),
    );
  }
}
