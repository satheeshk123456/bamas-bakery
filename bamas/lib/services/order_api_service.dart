import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import 'branch_service.dart';
import 'demo_data.dart';

/// Places a new order via bamas-admin-backend instead of writing to
/// Firestore directly. The backend does the Firestore write AND sends
/// the "new order" push to the admin app's FCM topic in the same
/// request — this is what replaces the old Cloud Function trigger, so
/// notifications work without Firebase's paid Blaze plan.
///
/// Everything else about orders (live status updates, choosing a
/// payment method) still goes through FirestoreService directly, since
/// those are just reads/writes the customer's own device is allowed to
/// do under the Firestore security rules.
class OrderApiService {
  Future<String> placeOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String customerName,
    required String customerPhone,
    required String address,
    double? lat,
    double? lng,
    String? fcmToken,
    String? userId,
  }) async {
    // Which branch has to cook and deliver this. The backend files the
    // order against its default branch if this is missing, so an older
    // build of the app never produces an order no manager can see.
    final branchId = BranchService.instance.currentId;
    if (kDemoMode) {
      return DemoStore.createOrder(
        items: items,
        totalAmount: totalAmount,
        customerName: customerName,
        customerPhone: customerPhone,
        address: address,
      );
    }

    final res = await http.post(
      Uri.parse('$kApiBaseUrl/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'items': items,
        'totalAmount': totalAmount,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'lat': lat,
        'lng': lng,
        'fcmToken': fcmToken,
        // Ties the order to the signed-in customer so it shows up under
        // "My Orders" and the backend can refuse anyone else reading it.
        'userId': userId,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Could not place order (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    final id = (data is Map ? data['id'] : null)?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Order placed but no order id was returned.');
    }
    return id;
  }
}

final orderApiService = OrderApiService();
