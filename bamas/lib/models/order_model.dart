
/// pending        -> just placed, waiting for admin's confirmation call
/// accepted       -> admin confirmed the order on the phone
/// rejected       -> admin could not fulfil the order
/// completed      -> delivered / picked up, order closed
const kOrderStatuses = ['pending', 'accepted', 'rejected', 'completed'];

class OrderLocation {
  final String address;
  final double? lat;
  final double? lng;

  OrderLocation({required this.address, this.lat, this.lng});

  factory OrderLocation.fromMap(Map<String, dynamic> map) => OrderLocation(
        address: map['address'] ?? '',
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'address': address,
        'lat': lat,
        'lng': lng,
      };
}

class OrderModel {
  final String id;

  /// Which branch this order was placed at. Null only for orders created
  /// before the multi-branch upgrade (the backend's migration backfills
  /// those). The order status screen uses it so the payment QR always
  /// belongs to the branch that took the order, even if the customer has
  /// since switched branches in the app.
  final String? branchId;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String customerName;
  final String customerPhone;
  final OrderLocation location;
  final String status; // pending | accepted | rejected | completed
  final String? paymentMethod; // gpay | cod | null
  final bool paymentConfirmedByCustomer;
  final String? fcmToken;
  final String? userId;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    this.branchId,
    required this.items,
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
    required this.location,
    required this.status,
    this.paymentMethod,
    this.paymentConfirmedByCustomer = false,
    this.fcmToken,
    this.userId,
    this.createdAt,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    return OrderModel(
      id: id,
      branchId: map['branchId'] as String?,
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      location: OrderLocation.fromMap(Map<String, dynamic>.from(map['location'] ?? {})),
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'],
      paymentConfirmedByCustomer: map['paymentConfirmedByCustomer'] ?? false,
      fcmToken: map['fcmToken'],
      userId: map['userId'],
      createdAt: _parseDate(map['createdAt']),
    );
  }

  /// The backend serialises dates as ISO8601 strings (Python's
  /// `.isoformat()`). Anything else becomes null rather than throwing
  /// while decoding a response -- that failure used to surface on-device
  /// with perfectly clean 200 OK server logs, which was hard to trace.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
