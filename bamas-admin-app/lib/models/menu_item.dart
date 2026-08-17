class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final String categoryId;

  /// Photo shown on the customer app. Uploaded from the admin app's menu
  /// editor and stored server-side; this is just the URL.
  final String? imageUrl;

  /// Offer / discount fields — at most one of [discountPercent] /
  /// [discountAmount] is normally set at a time. Both are optional; leave
  /// both null for "no offer".
  final double? discountPercent; // e.g. 20 -> "20% OFF"
  final double? discountAmount; // e.g. 20 -> "₹20 off"

  /// Short badge text shown alongside the discount on the customer app,
  /// e.g. "Combo Deal", "Weekend Special". Optional even when a discount
  /// is set, and can also be used alone as a plain tag like "Best Seller".
  final String? offerLabel;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    required this.categoryId,
    this.imageUrl,
    this.discountPercent,
    this.discountAmount,
    this.offerLabel,
  });

  /// True when there's a live discount to show/apply.
  bool get hasDiscount =>
      (discountPercent != null && discountPercent! > 0) || (discountAmount != null && discountAmount! > 0);

  /// Price after applying the discount, clamped to a minimum of 0.
  /// Percent takes priority if both are somehow set.
  double get effectivePrice {
    if (discountPercent != null && discountPercent! > 0) {
      final discounted = price * (1 - discountPercent! / 100);
      return discounted < 0 ? 0 : discounted;
    }
    if (discountAmount != null && discountAmount! > 0) {
      final discounted = price - discountAmount!;
      return discounted < 0 ? 0 : discounted;
    }
    return price;
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        isAvailable: json['isAvailable'] as bool? ?? true,
        categoryId: (json['categoryId'] ?? '').toString(),
        imageUrl: (json['imageUrl'] as String?)?.trim().isEmpty == true ? null : json['imageUrl'] as String?,
        discountPercent: (json['discountPercent'] as num?)?.toDouble(),
        discountAmount: (json['discountAmount'] as num?)?.toDouble(),
        offerLabel: (json['offerLabel'] as String?)?.trim().isEmpty == true ? null : json['offerLabel'] as String?,
      );

  /// Body for PATCH /menu/items/{id} — only the fields the editor screen
  /// changes. Send explicit `null`s so the backend can clear a discount
  /// (e.g. "remove offer").
  Map<String, dynamic> toUpdateJson() => {
        'price': price,
        'imageUrl': imageUrl,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'offerLabel': offerLabel,
      };

  MenuItem copyWith({
    String? name,
    String? description,
    double? price,
    bool? isAvailable,
    String? categoryId,
    String? imageUrl,
    bool clearImageUrl = false,
    double? discountPercent,
    bool clearDiscountPercent = false,
    double? discountAmount,
    bool clearDiscountAmount = false,
    String? offerLabel,
    bool clearOfferLabel = false,
  }) =>
      MenuItem(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        isAvailable: isAvailable ?? this.isAvailable,
        categoryId: categoryId ?? this.categoryId,
        imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
        discountPercent: clearDiscountPercent ? null : (discountPercent ?? this.discountPercent),
        discountAmount: clearDiscountAmount ? null : (discountAmount ?? this.discountAmount),
        offerLabel: clearOfferLabel ? null : (offerLabel ?? this.offerLabel),
      );
}
