import 'package:cloud_firestore/cloud_firestore.dart';

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
  final Timestamp? createdAt;

  OrderModel({
    required this.id,
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
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  /// Orders reach this model from two different sources: the native
  /// Firestore SDK (admin/demo streams), which hands back a real
  /// [Timestamp], and the bamas-admin-backend HTTP API
  /// (GET /account/orders), which JSON-serialises the same field as an
  /// ISO8601 string via Python's `.isoformat()`. Assigning that string
  /// straight into a `Timestamp?` field used to throw a runtime
  /// TypeError the moment an order came back over HTTP (the server
  /// logs looked perfectly clean -- 200 OK -- because the failure only
  /// happened afterwards, on-device, while decoding the response) --
  /// this normalises either shape instead of assuming one.
  static Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }
}
