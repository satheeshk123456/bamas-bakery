import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String customerName;
  final double rating; // 1..5
  final String comment;
  final Timestamp? createdAt;

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
        createdAt: map['createdAt'],
      );
}

class Enquiry {
  final String id;
  final String name;
  final String phone;
  final String message;
  final bool handled;
  final Timestamp? createdAt;

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
        createdAt: map['createdAt'],
      );
}
