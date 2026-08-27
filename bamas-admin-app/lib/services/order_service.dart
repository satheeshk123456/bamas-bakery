import '../app_config.dart';
import '../models/order.dart';
import 'api_client.dart';
import 'demo_data.dart';

class OrderService {
  /// [fromDate]/[toDate] are 'YYYY-MM-DD' and inclusive (the shop's own
  /// IST calendar day) -- used by the Reports screen's date filter.
  /// [limit] defaults to a small page for the status tabs; pass a much
  /// bigger number (see Reports screen) when a date filter should return
  /// everything in range instead of just the latest page.
  Future<List<Order>> listOrders({
    String? status,
    String? fromDate,
    String? toDate,
    int limit = 50,
  }) async {
    if (kDemoMode) {
      final all = demoOrders();
      return status == null ? all : all.where((o) => o.status == status).toList();
    }
    final query = <String, String>{'limit': '$limit'};
    if (status != null) query['status'] = status;
    if (fromDate != null) query['from_date'] = fromDate;
    if (toDate != null) query['to_date'] = toDate;
    final result = await apiClient.get('/orders', query: query);
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

  /// Downloads a CSV of orders in the given range for the shop's own
  /// records (e.g. "the whole of last month") -- the Reports screen's
  /// Download button.
  Future<List<int>> exportCsv({String? status, String? fromDate, String? toDate}) async {
    if (kDemoMode) throw UnimplementedError('Export is not available in demo mode.');
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (fromDate != null) query['from_date'] = fromDate;
    if (toDate != null) query['to_date'] = toDate;
    return apiClient.getBytes('/orders/export', query: query);
  }
}

final orderService = OrderService();
