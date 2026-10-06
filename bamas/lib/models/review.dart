
class Review {
  final String id;
  final String customerName;
  final double rating; // 1..5
  final String comment;
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.customerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
        id: id,
        customerName: map['customerName'] ?? 'Guest',
        rating: (map['rating'] ?? 5).toDouble(),
        comment: map['comment'] ?? '',
        createdAt: _parseDate(map['createdAt']),
      );
}

class Enquiry {
  final String id;
  final String name;
  final String phone;
  final String message;
  final bool handled;
  final DateTime? createdAt;

  Enquiry({
    required this.id,
    required this.name,
    required this.phone,
    required this.message,
    this.handled = false,
    this.createdAt,
  });

  factory Enquiry.fromMap(String id, Map<String, dynamic> map) => Enquiry(
        id: id,
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        message: map['message'] ?? '',
        handled: map['handled'] ?? false,
        createdAt: _parseDate(map['createdAt']),
      );
}

/// The backend sends dates as ISO8601 strings (Python `.isoformat()`).
/// Anything unparseable becomes null rather than throwing while decoding.
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
