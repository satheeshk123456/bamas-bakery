import '../app_config.dart';
import '../models/order.dart';
import 'api_client.dart';
import 'demo_data.dart';

class OrderService {
  Future<List<Order>> listOrders({String? status}) async {
    if (kDemoMode) {
      final all = demoOrders();
      return status == null ? all : all.where((o) => o.status == status).toList();
    }
    final result = await apiClient.get('/orders', query: status != null ? {'status': status} : null);
    return (result as List).map((e) => Order.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Order> getOrder(String id) async {
    if (kDemoMode) {
      return demoOrders().firstWhere((o) => o.id == id);
    }
    final result = await apiClient.get('/orders/$id');
    return Order.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<void> updateStatus(String id, String status) async {
    if (kDemoMode) return; // no-op in demo mode
    await apiClient.patch('/orders/$id/status', body: {'status': status});
  }
}

final orderService = OrderService();
