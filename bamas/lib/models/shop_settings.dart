class ShopSettings {
  final bool isOpen;
  final String shopName;
  final String logoUrl;
  final String gpayQrUrl;
  final String upiId;
  final String contactPhone;

  /// Hero banner (the big photo section on the home screen).
  /// All three are editable from the admin panel's Settings page, so the
  /// client can change their own headline and shop photo without a rebuild.
  final String heroImageUrl;
  final String heroHeadline;
  final String heroTagline;
  final String address;

  ShopSettings({
    required this.isOpen,
    required this.shopName,
    required this.logoUrl,
    required this.gpayQrUrl,
    required this.upiId,
    required this.contactPhone,
    this.heroImageUrl = '',
    this.heroHeadline = 'Your Burger Cravings, Sorted',
    this.heroTagline = 'Taste the Love, Feel the Quality',
    this.address = '',
  });

  factory ShopSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return ShopSettings(
        isOpen: true,
        shopName: "Bama's Burger Box",
        logoUrl: '',
        gpayQrUrl: '',
        upiId: '',
        contactPhone: '',
      );
    }
    return ShopSettings(
      isOpen: map['isOpen'] ?? true,
      shopName: map['shopName'] ?? "Bama's Burger Box",
      logoUrl: map['logoUrl'] ?? '',
      gpayQrUrl: map['gpayQrUrl'] ?? '',
      upiId: map['upiId'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      heroImageUrl: map['heroImageUrl'] ?? '',
      heroHeadline: (map['heroHeadline'] as String?)?.isNotEmpty == true
          ? map['heroHeadline']
          : 'Your Burger Cravings, Sorted',
      heroTagline: (map['heroTagline'] as String?)?.isNotEmpty == true
          ? map['heroTagline']
          : 'Taste the Love, Feel the Quality',
      address: map['address'] ?? '',
    );
  }
}
