/// Everything editable from the admin app's Settings screen: contact
/// info, the home-page hero banner text, the weekend-offer banner, and
/// four photos (logo, hero, GPay QR, weekend-offer). Mirrors the shape
/// bamas's own ShopSettings model reads, since both apps point at the
/// SAME shopSettings/main Firestore document -- this one is just also
/// able to send updates back (see services/shop_service.dart).
class AdminShopSettings {
  final bool isOpen;
  final String shopName;
  final String contactPhone;
  final String address;
  final String upiId;
  final String logoUrl;
  final String gpayQrUrl;
  final String heroImageUrl;
  final String heroHeadline;
  final String heroTagline;
  final bool weekendOfferEnabled;
  final String weekendOfferText;
  final String weekendOfferImageUrl;

  AdminShopSettings({
    required this.isOpen,
    required this.shopName,
    required this.contactPhone,
    required this.address,
    required this.upiId,
    required this.logoUrl,
    required this.gpayQrUrl,
    required this.heroImageUrl,
    required this.heroHeadline,
    required this.heroTagline,
    required this.weekendOfferEnabled,
    required this.weekendOfferText,
    required this.weekendOfferImageUrl,
  });

  factory AdminShopSettings.fromJson(Map<String, dynamic> json) => AdminShopSettings(
        isOpen: json['isOpen'] as bool? ?? true,
        shopName: (json['shopName'] ?? '').toString(),
        contactPhone: (json['contactPhone'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
        upiId: (json['upiId'] ?? '').toString(),
        logoUrl: (json['logoUrl'] ?? '').toString(),
        gpayQrUrl: (json['gpayQrUrl'] ?? '').toString(),
        heroImageUrl: (json['heroImageUrl'] ?? '').toString(),
        heroHeadline: (json['heroHeadline'] ?? '').toString(),
        heroTagline: (json['heroTagline'] ?? '').toString(),
        weekendOfferEnabled: json['weekendOfferEnabled'] as bool? ?? false,
        weekendOfferText: (json['weekendOfferText'] ?? '').toString(),
        weekendOfferImageUrl: (json['weekendOfferImageUrl'] ?? '').toString(),
      );

  /// Body for PATCH /shop-settings -- every plain text/boolean field.
  /// Photos are NOT included here; they go through the separate
  /// POST /shop-settings/image upload (see ShopService.uploadImage).
  Map<String, dynamic> toUpdateJson() => {
        'isOpen': isOpen,
        'shopName': shopName,
        'contactPhone': contactPhone,
        'address': address,
        'upiId': upiId,
        'heroHeadline': heroHeadline,
        'heroTagline': heroTagline,
        'weekendOfferEnabled': weekendOfferEnabled,
        'weekendOfferText': weekendOfferText,
      };

  AdminShopSettings copyWith({
    bool? isOpen,
    String? shopName,
    String? contactPhone,
    String? address,
    String? upiId,
    String? logoUrl,
    String? gpayQrUrl,
    String? heroImageUrl,
    String? heroHeadline,
    String? heroTagline,
    bool? weekendOfferEnabled,
    String? weekendOfferText,
    String? weekendOfferImageUrl,
  }) =>
      AdminShopSettings(
        isOpen: isOpen ?? this.isOpen,
        shopName: shopName ?? this.shopName,
        contactPhone: contactPhone ?? this.contactPhone,
        address: address ?? this.address,
        upiId: upiId ?? this.upiId,
        logoUrl: logoUrl ?? this.logoUrl,
        gpayQrUrl: gpayQrUrl ?? this.gpayQrUrl,
        heroImageUrl: heroImageUrl ?? this.heroImageUrl,
        heroHeadline: heroHeadline ?? this.heroHeadline,
        heroTagline: heroTagline ?? this.heroTagline,
        weekendOfferEnabled: weekendOfferEnabled ?? this.weekendOfferEnabled,
        weekendOfferText: weekendOfferText ?? this.weekendOfferText,
        weekendOfferImageUrl: weekendOfferImageUrl ?? this.weekendOfferImageUrl,
      );
}
