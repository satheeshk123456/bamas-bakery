/// A home-page promo banner shown in the customer app's offers carousel.
/// Fully admin-controlled: add, edit, disable, or delete any time with no
/// app update needed (see bamas-admin-backend's /offers endpoints and
/// bamas's OfferModel + offers carousel, which reads the same Firestore
/// collection directly).
class Offer {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isActive;
  final int sortOrder;

  Offer({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isActive,
    required this.sortOrder,
  });

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        subtitle: (json['subtitle'] ?? '').toString(),
        imageUrl: (json['imageUrl'] ?? '').toString(),
        isActive: json['isActive'] as bool? ?? true,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Offer copyWith({String? imageUrl, bool? isActive}) => Offer(
        id: id,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder,
      );
}
