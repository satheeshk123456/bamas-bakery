/// A home-page promo banner. Admin-controlled end to end (see the admin
/// app's Offers screen + bamas-admin-backend's /offers endpoints) --
/// this app only ever reads the `offers` Firestore collection directly
/// (public read, see firestore.rules), same pattern as categories and
/// menu items, so a new offer appears in the carousel immediately.
class OfferModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isActive;
  final int sortOrder;

  OfferModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isActive,
    required this.sortOrder,
  });

  factory OfferModel.fromMap(String id, Map<String, dynamic> map) => OfferModel(
        id: id,
        title: (map['title'] ?? '').toString(),
        subtitle: (map['subtitle'] ?? '').toString(),
        imageUrl: (map['imageUrl'] ?? '').toString(),
        isActive: map['isActive'] ?? true,
        sortOrder: (map['sortOrder'] ?? 0) as int,
      );
}
