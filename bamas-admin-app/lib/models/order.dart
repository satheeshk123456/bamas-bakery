class OrderItemLine {
  final String name;
  final double price;
  final int quantity;

  OrderItemLine({required this.name, required this.price, required this.quantity});

  factory OrderItemLine.fromJson(Map<String, dynamic> json) => OrderItemLine(
        name: (json['name'] ?? 'Item').toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

class Order {
  final String id;
  final List<OrderItemLine> items;
  final double totalAmount;
  final String customerName;
  final String customerPhone;
  final String address;
  final String status; // pending | accepted | rejected | completed
  final String? paymentMethod;
  final String? createdAt;

  Order({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.status,
    this.paymentMethod,
    this.createdAt,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  factory Order.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    return Order(
      id: (json['id'] ?? '').toString(),
      items: ((json['items'] as List?) ?? [])
          .map((e) => OrderItemLine.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      customerName: (json['customerName'] ?? 'Customer').toString(),
      customerPhone: (json['customerPhone'] ?? '').toString(),
      address: (location['address'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
