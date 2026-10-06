/// One shop location.
///
/// A branch owns the things that differ between locations: its own phone
/// number (orders are WhatsApp'd there), its own UPI id and QR (each branch
/// banks its own money), its own address, and its own open/closed switch.
/// The brand-level things — shop name, logo, hero banner, offers — stay in
/// ShopSettings and are shared by every branch.
class Branch {
  final String id;
  final String name;
  final String address;
  final String contactPhone;
  final String upiId;
  final String gpayQrUrl;
  final String imageUrl;
  final bool isOpen;
  final int sortOrder;

  const Branch({
    required this.id,
    required this.name,
    this.address = '',
    this.contactPhone = '',
    this.upiId = '',
    this.gpayQrUrl = '',
    this.imageUrl = '',
    this.isOpen = true,
    this.sortOrder = 0,
  });

  factory Branch.fromMap(String id, Map<String, dynamic> map) => Branch(
        id: id,
        name: map['name'] ?? '',
        address: map['address'] ?? '',
        contactPhone: map['contactPhone'] ?? '',
        upiId: map['upiId'] ?? '',
        gpayQrUrl: map['gpayQrUrl'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        isOpen: map['isOpen'] ?? true,
        sortOrder: (map['sortOrder'] ?? 0) as int,
      );

  /// Only the id and name are kept on disk. Everything else (open/closed,
  /// UPI id, phone) is re-fetched on launch, because a stale "open" flag or
  /// an out-of-date UPI id cached on a phone for weeks would be worse than
  /// no cache at all.
  Map<String, dynamic> toStoredMap() => {'id': id, 'name': name};

  factory Branch.fromStoredMap(Map<String, dynamic> map) =>
      Branch(id: map['id'] ?? '', name: map['name'] ?? '');
}
