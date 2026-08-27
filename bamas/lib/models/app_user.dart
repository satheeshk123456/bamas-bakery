/// A customer's account profile, stored in Firestore at `users/{uid}`.
/// This is separate from FirebaseAuth's own User object (which really
/// only carries uid/email) — it's the extra profile info collected at
/// registration and shown on the Account screen.
class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String email;

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
      };
}
