/// One submission from the customer app's Enquiry ("contact us") form.
/// Previously written to Firestore with no way for the admin to ever see
/// it -- see bamas-admin-backend's GET /enquiries.
class Enquiry {
  final String id;
  final String name;
  final String phone;
  final String message;
  final bool handled;
  final String? createdAt;

  Enquiry({
    required this.id,
    required this.name,
    required this.phone,
    required this.message,
    required this.handled,
    this.createdAt,
  });

  factory Enquiry.fromJson(Map<String, dynamic> json) => Enquiry(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        handled: json['handled'] as bool? ?? false,
        createdAt: json['createdAt']?.toString(),
      );
}
