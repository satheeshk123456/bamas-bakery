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
      createdAt: map['createdAt'],
    );
  }
}
