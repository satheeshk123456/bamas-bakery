/// A star rating + comment left on the customer app's Reviews screen.
/// See bamas-admin-backend's GET /reviews / DELETE /reviews/{id}.
class AdminReview {
  final String id;
  final String customerName;
  final double rating;
  final String comment;
  final String? createdAt;

  AdminReview({
    required this.id,
    required this.customerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory AdminReview.fromJson(Map<String, dynamic> json) => AdminReview(
        id: (json['id'] ?? '').toString(),
        customerName: (json['customerName'] ?? 'Customer').toString(),
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        comment: (json['comment'] ?? '').toString(),
        createdAt: json['createdAt']?.toString(),
      );
}
