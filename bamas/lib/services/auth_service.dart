import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';
import '../models/app_user.dart';
import '../models/order_model.dart';
import 'api_service.dart';

/// A minimal view of "who's signed in". Kept deliberately independent of
/// any auth provider so demo mode (kDemoMode) can fake a signed-in user.
class AuthUser {
  final String uid;
  final String email;
  AuthUser({required this.uid, required this.email});
}

/// Thrown when the backend rejects a register/login call. Carries the
/// human-readable message the backend already sent back.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

/// Accounts are handled entirely by bamas-admin-backend. Register and
/// login are POSTs to `$kApiBaseUrl/account/...`; the backend checks the
/// bcrypt password hash in MongoDB and returns its own JWT.
///
/// This app simply stores that JWT (in SharedPreferences, so the session
/// survives an app restart) and sends it as `Authorization: Bearer ...`
/// on customer requests. Firebase is no longer involved in identity at
/// all — the app keeps Firebase only for FCM push notifications.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kTokenKey = 'auth_access_token';
  static const _kUidKey = 'auth_uid';
  static const _kEmailKey = 'auth_email';

  String? _token;
  AuthUser? _user;
  bool _restored = false;
  final _controller = StreamController<AuthUser?>.broadcast();

  /// The stored JWT, or null when signed out. Other services (see
  /// ApiService) use this to authenticate customer-only requests.
  String? get token => _token;

  /// Reloads any session saved on this device. Call once at startup,
  /// before AuthGate decides which screen to show, otherwise a returning
  /// customer is briefly shown the login screen.
  Future<void> restoreSession() async {
    if (_restored) return;
    _restored = true;
    if (kDemoMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kTokenKey);
      final uid = prefs.getString(_kUidKey);
      if (token != null && uid != null) {
        _token = token;
        _user = AuthUser(uid: uid, email: prefs.getString(_kEmailKey) ?? '');
      }
    } catch (_) {
      // Storage unavailable — treat as signed out rather than crashing.
    }
    _controller.add(_user);
  }

  Future<void> _persist(String token, String uid, String email) async {
    _token = token;
    _user = AuthUser(uid: uid, email: email);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await prefs.setString(_kUidKey, uid);
      await prefs.setString(_kEmailKey, email);
    } catch (_) {
      // Session still works for this run even if it can't be saved.
    }
    _controller.add(_user);
  }

  Stream<AuthUser?> authStateChanges() {
    Future.microtask(() => _controller.add(_user));
    return _controller.stream;
  }

  AuthUser? get currentUser => _user;

  Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (kDemoMode) {
      final uid = 'demo-${DateTime.now().millisecondsSinceEpoch}';
      _user = AuthUser(uid: uid, email: email.trim());
      _controller.add(_user);
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
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _persist(data['accessToken'] as String, data['uid'] as String, email.trim());
  }

  Future<void> login({required String email, required String password}) async {
    if (kDemoMode) {
      _user = AuthUser(uid: _user?.uid ?? 'demo-user', email: email.trim());
      _controller.add(_user);
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
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _persist(data['accessToken'] as String, data['uid'] as String, email.trim());
  }

  /// Password reset by email isn't available (it used to be Firebase's
  /// mail service). The backend replies with a clear message telling the
  /// customer to contact the shop, which is surfaced to them as-is.
  Future<void> resetPassword(String email) async {
    if (kDemoMode) return;
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/account/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthException(_extractDetail(res,
          fallback: 'Please contact the shop to reset your password.'));
    }
  }

  /// Called when the backend rejects our token (401). Clears the session
  /// so AuthGate shows the login screen, rather than leaving the app
  /// looking signed in while every request quietly fails.
  Future<void> handleUnauthorized() async {
    if (_token == null && _user == null) return;   // already signed out
    await logout();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.clearCache();
    if (!kDemoMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kTokenKey);
        await prefs.remove(_kUidKey);
        await prefs.remove(_kEmailKey);
      } catch (_) {
        // Already cleared in memory; nothing else to do.
      }
    }
    _controller.add(null);
  }

  /// GET /account/me
  Future<AppUser?> fetchProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    if (kDemoMode) return AppUser(uid: uid, name: 'Demo User', phone: '9999999999', email: _user!.email);
    final data = await ApiService.instance.getMyProfile();
    return data == null ? null : AppUser.fromMap(uid, data);
  }

  /// GET /account/orders
  Future<List<OrderModel>> fetchMyOrders() async {
    if (currentUser?.uid == null) return [];
    if (kDemoMode) return [];
    return ApiService.instance.myOrders();
  }

  String _extractDetail(http.Response res, {required String fallback}) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {
      // Body wasn't JSON (e.g. a raw 500 page) — fall through.
    }
    return fallback;
  }

  /// Turns whatever register()/login() threw into a short message that's
  /// safe to show directly in a SnackBar.
  static String friendlyError(Object e) {
    if (e is AuthException) return e.message;
    return 'Something went wrong. Please try again.';
  }
}
