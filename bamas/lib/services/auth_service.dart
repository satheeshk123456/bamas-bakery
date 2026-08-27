import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../models/app_user.dart';
import '../models/order_model.dart';
import 'firestore_service.dart';

/// A minimal, Firebase-independent view of "who's signed in" — so demo
/// mode (kDemoMode) can fake a signed-in user without ever touching
/// Firebase Auth, same as the rest of the app fakes Firestore.
class AuthUser {
  final String uid;
  final String email;
  AuthUser({required this.uid, required this.email});
}

/// Thrown when the backend rejects a register/login/etc. call. Carries
/// the human-readable message the backend already sent back.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

/// All account functionality lives in bamas-admin-backend, not in this
/// app: register, login and "forgot password" are POSTs to
/// `$kApiBaseUrl/account/...`, and the backend does the real work (it
/// creates the Firebase Auth user itself via the Admin SDK, checks
/// passwords via Google's Identity Toolkit REST API, and writes/reads
/// the users/{uid} profile doc and the customer's own orders).
///
/// The ONE thing that can't move server-side is establishing the actual
/// signed-in session on this device — only the Firebase Auth *client*
/// SDK can do that, so register/login end by handing the backend's
/// custom token to `signInWithCustomToken`. That single call just
/// adopts a session the backend already vouched for; it doesn't check
/// anything itself. From then on, AuthService.authStateChanges() (used
/// by AuthGate) reflects that session automatically.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _firestore = FirestoreService();

  // ---- demo mode state (kDemoMode == true) ----
  AuthUser? _demoUser;
  final _demoController = StreamController<AuthUser?>.broadcast();

  Stream<AuthUser?> authStateChanges() {
    if (kDemoMode) {
      Future.microtask(() => _demoController.add(_demoUser));
      return _demoController.stream;
    }
    return fb.FirebaseAuth.instance.authStateChanges().map(
        (u) => u == null ? null : AuthUser(uid: u.uid, email: u.email ?? ''));
  }

  AuthUser? get currentUser {
    if (kDemoMode) return _demoUser;
    final u = fb.FirebaseAuth.instance.currentUser;
    return u == null ? null : AuthUser(uid: u.uid, email: u.email ?? '');
  }

  Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (kDemoMode) {
      final uid = 'demo-${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.saveUserProfile(
          uid: uid, name: name.trim(), phone: phone.trim(), email: email.trim());
      _demoUser = AuthUser(uid: uid, email: email.trim());
      _demoController.add(_demoUser);
      return;
    }

    final res = await http.post(
      Uri.parse('$kApiBaseUrl/account/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthException(_extractDetail(res, fallback: 'Could not create your account.'));
    }
    final token = (jsonDecode(res.body) as Map)['customToken'] as String;
    await fb.FirebaseAuth.instance.signInWithCustomToken(token);
  }

  Future<void> login({required String email, required String password}) async {
    if (kDemoMode) {
      final uid = _demoUser?.uid ?? 'demo-user';
      // Make sure a profile exists no matter how demo mode was entered,
      // so the Account screen always has something to show.
      await _firestore.saveUserProfile(
          uid: uid, name: 'Demo User', phone: '9999999999', email: email.trim());
      _demoUser = AuthUser(uid: uid, email: email.trim());
      _demoController.add(_demoUser);
      return;
    }

    final res = await http.post(
      Uri.parse('$kApiBaseUrl/account/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthException(_extractDetail(res, fallback: 'Incorrect email or password.'));
    }
    final token = (jsonDecode(res.body) as Map)['customToken'] as String;
    await fb.FirebaseAuth.instance.signInWithCustomToken(token);
  }

  Future<void> resetPassword(String email) async {
    if (kDemoMode) return; // nothing to reset in demo mode
    await http.post(
      Uri.parse('$kApiBaseUrl/account/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    // The backend always reports success (so this endpoint can't be used
    // to check which emails are registered) — nothing to branch on here.
  }

  Future<void> logout() async {
    if (kDemoMode) {
      _demoUser = null;
      _demoController.add(null);
      return;
    }
    // Purely local — there's no backend session to end, Firebase Auth's
    // client SDK just clears/stops refreshing the token on this device.
    await fb.FirebaseAuth.instance.signOut();
  }

  /// Reads the signed-in account's profile via GET /account/me. Used by
  /// AccountScreen instead of a live Firestore stream now that the
  /// backend, not this app, owns reading/writing users/{uid}.
  Future<AppUser?> fetchProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    if (kDemoMode) return _firestore.userProfileStream(uid).first;

    final token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return null;
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/account/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AppUser.fromMap(uid, data);
  }

  /// Lists the signed-in account's own orders via GET /account/orders.
  /// Used by OrderHistoryScreen instead of a live Firestore query now
  /// that the backend owns reading orders by userId.
  Future<List<OrderModel>> fetchMyOrders() async {
    final uid = currentUser?.uid;
    if (uid == null) return [];
    if (kDemoMode) return _firestore.myOrdersStream(uid).first;

    final token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return [];
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/account/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    return list
        .map((m) => OrderModel.fromMap(m['id'] as String, m as Map<String, dynamic>))
        .toList();
  }

  String _extractDetail(http.Response res, {required String fallback}) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {
      // Body wasn't JSON (e.g. a raw 500 page) — fall through to fallback.
    }
    return fallback;
  }

  /// Turns whatever register()/login() threw into a short message that's
  /// safe to show directly in a SnackBar.
  static String friendlyError(Object e) {
    if (e is AuthException) return e.message;
    if (e is fb.FirebaseAuthException) {
      // Can still happen from signInWithCustomToken itself (e.g. a
      // network error, or a malformed/expired custom token).
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
