import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/offer.dart';
import '../models/app_user.dart';
import '../models/branch.dart';
import '../models/order_model.dart';
import '../models/review.dart';
import '../models/shop_settings.dart';
import 'auth_service.dart';
import 'branch_service.dart';
import 'demo_data.dart';

/// Every read/write goes through this one class. Screens never talk to
/// the network directly — keeps the data layer swappable and easy to
/// debug. When kDemoMode is true, local fake data is returned instead
/// and no request is ever made.
///
/// This replaces the old FirestoreService. All data now comes from
/// bamas-admin-backend over HTTP; nothing reads a database directly any
/// more. Where the old code used live Firestore snapshots, these methods
/// poll the backend on an interval and expose the same Stream API, so
/// the screens using StreamBuilder did not have to change.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// How often each kind of data is re-fetched. Menu content barely
  /// changes, so it is polled lazily; a live order is what the customer
  /// is actively watching, so it refreshes quickly.
  static const _menuInterval = Duration(seconds: 60);
  static const _orderInterval = Duration(seconds: 8);
  static const _myOrdersInterval = Duration(seconds: 20);

  /// Last successful value per endpoint, kept for the life of the app.
  /// Without this, every time a screen is opened its StreamBuilder
  /// subscribes fresh, fires a request, and shows a spinner - so going
  /// Home -> Menu -> Home reloaded everything each time. Now a screen
  /// paints instantly from the last known value and only refetches when
  /// that value is actually stale.
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cachedAt = {};

  /// Drop everything cached. Called on logout so the next customer on
  /// this phone never sees the previous one's data.
  static void clearCache() {
    _cache.clear();
    _cachedAt.clear();
  }

  Map<String, String> get _authHeaders {
    final token = AuthService.instance.token;
    return token == null
        ? <String, String>{}
        : <String, String>{'Authorization': 'Bearer $token'};
  }

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  /// Repeatedly runs [fetch], yielding each result. Emits [orElse] if the
  /// very first attempt fails, so a screen shows empty content rather
  /// than spinning forever; after that a failed refresh is ignored and
  /// the last good value stays on screen. Polling stops automatically
  /// when the listener cancels (i.e. when the screen is disposed).
  Stream<T> _poll<T>(String cacheKey, Future<T> Function() fetch, Duration every,
      T orElse) async* {
    var delivered = false;

    // Paint immediately from cache - no spinner when returning to a screen.
    if (_cache.containsKey(cacheKey)) {
      delivered = true;
      yield _cache[cacheKey] as T;
      // Still fresh? wait out the remainder instead of refetching at once.
      final age = DateTime.now().difference(_cachedAt[cacheKey]!);
      if (age < every) await Future<void>.delayed(every - age);
    }

    while (true) {
      try {
        final value = await fetch();
        _cache[cacheKey] = value;
        _cachedAt[cacheKey] = DateTime.now();
        delivered = true;
        yield value;
      } catch (_) {
        // A failed refresh keeps the last good value on screen.
        if (!delivered) {
          delivered = true;
          yield orElse;
        }
      }
      await Future<void>.delayed(every);
    }
  }

  Future<dynamic> _get(String path, {bool auth = false}) async {
    final res = await http.get(_uri(path), headers: auth ? _authHeaders : const <String, String>{});
    if (auth && res.statusCode == 401) {
      // Session no longer valid. Sign out so AuthGate shows the login
      // screen, instead of leaving the app in a half-logged-in state
      // where every request silently fails.
      await AuthService.instance.handleUnauthorized();
      throw Exception('Session expired');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET $path failed (${res.statusCode})');
    }
    return jsonDecode(res.body);
  }

  Future<void> _send(String method, String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth) ..._authHeaders,
    };
    final req = http.Request(method, _uri(path))
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send());
    if (auth && res.statusCode == 401) {
      await AuthService.instance.handleUnauthorized();
      throw Exception('Session expired');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = 'Something went wrong. Please try again.';
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['detail'] != null) detail = data['detail'].toString();
      } catch (_) {
        // Not JSON — keep the generic message.
      }
      throw Exception(detail);
    }
  }

  /// The branch this phone is ordering from, or null before one is picked.
  String? get _branchId => BranchService.instance.currentId;

  /// Looks a branch up from the list BranchService already holds, fetching
  /// it only if that list is empty (e.g. the app was restarted straight
  /// into an order screen, so the picker never ran this session).
  ///
  /// Pass [fresh] when the branch's LIVE state matters rather than just
  /// its name and address. `isOpen` lives on the branch, and the list in
  /// memory is only refreshed when the branch picker runs -- so reading
  /// open/closed from it meant the owner could shut a branch and every
  /// customer's app kept showing "Open" until the app was force-closed
  /// and relaunched. One extra GET /branches per poll is a cheap price
  /// for the shop actually being able to shut.
  Future<Branch?> _branchFor(String? branchId, {bool fresh = false}) async {
    final id = branchId ?? _branchId;
    if (id == null || id.isEmpty) return null;
    final svc = BranchService.instance;

    if (fresh) {
      try {
        for (final b in await svc.fetchBranches()) {
          if (b.id == id) return b;
        }
      } catch (_) {
        // Offline -- fall through to whatever is already in memory, which
        // is better than losing the branch's phone number and UPI id.
      }
    }

    for (final b in svc.all) {
      if (b.id == id) return b;
    }
    try {
      for (final b in await svc.fetchBranches()) {
        if (b.id == id) return b;
      }
    } catch (_) {
      // Offline: fall back to the brand-wide settings below.
    }
    return null;
  }

  // ---------- Shop settings (open/closed, logo, hero, GPay QR) ----------
  /// Brand-wide settings with the BRANCH's own values laid over the top.
  ///
  /// This one overlay is what makes the rest of the app branch-aware
  /// without touching it: the Open/Closed pill on the home screen, the
  /// WhatsApp number the order is sent to at checkout, the UPI id the
  /// payment QR is built from, and the "call the shop" number on the order
  /// screen all read these fields. Get this wrong and a customer pays the
  /// wrong branch -- which is exactly why it is done in ONE place rather
  /// than screen by screen.
  ///
  /// [branchId] overrides the currently selected branch. The order status
  /// screen passes the branch the ORDER was placed at, so that a customer
  /// who has since switched branches still pays the right shop.
  Stream<ShopSettings> shopSettingsStream({String? branchId}) {
    if (kDemoMode) return Stream.value(DemoStore.settings);
    final id = branchId ?? _branchId;
    return _poll<ShopSettings>(
      'shop:${id ?? 'none'}',
      () async {
        final data = await _get('/shop-settings');
        // 404 simply means the shop has not been configured yet.
        final map = data == null ? <String, dynamic>{} : Map<String, dynamic>.from(data);

        final branch = await _branchFor(id, fresh: true);
        if (branch != null) {
          // TWO switches decide whether this branch is taking orders, and
          // CLOSED WINS:
          //
          //   Settings > "Shop is open"    the master switch -- shuts
          //                                every branch at once
          //   Branches > that branch's     shuts just that one
          //
          // This used to be a plain `= branch.isOpen`, which quietly made
          // the master switch do nothing at all once branches existed:
          // the owner set the shop closed in Settings and every customer's
          // app carried on saying Open. A missing flag counts as open, so
          // a shop that has never touched either switch is unaffected.
          final brandOpen = map['isOpen'] != false;
          map['isOpen'] = brandOpen && branch.isOpen;

          if (branch.contactPhone.isNotEmpty) map['contactPhone'] = branch.contactPhone;
          if (branch.address.isNotEmpty) map['address'] = branch.address;
          if (branch.upiId.isNotEmpty) map['upiId'] = branch.upiId;
          if (branch.gpayQrUrl.isNotEmpty) map['gpayQrUrl'] = branch.gpayQrUrl;
          // Brand fields (shopName, logo, hero, weekend offer) are left
          // alone -- one brand, many branches.
        }
        return ShopSettings.fromMap(map.isEmpty ? null : map);
      },
      _menuInterval,
      ShopSettings.fromMap(null),
    );
  }

  // ---------- Categories ----------
  Stream<List<CategoryModel>> categoriesStream() {
    if (kDemoMode) return Stream.value(DemoStore.categories);
    return _poll<List<CategoryModel>>(
      'categories',
      () async {
        final list = (await _get('/menu/categories') as List?) ?? const [];
        final cats = list
            .map((m) => CategoryModel.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return cats;
      },
      _menuInterval,
      const <CategoryModel>[],
    );
  }

  // ---------- Menu items ----------
  Stream<List<MenuItem>> menuItemsStream({String? categoryId}) {
    if (kDemoMode) {
      final items = categoryId == null
          ? DemoStore.items
          : DemoStore.items.where((i) => i.categoryId == categoryId).toList();
      return Stream.value(items);
    }
    return _poll<List<MenuItem>>(
      // The branch is part of the cache key: two branches have different
      // menus and prices, so sharing one cached list between them would
      // show the wrong food after switching.
      'items:${_branchId ?? 'all'}:${categoryId ?? 'all'}',
      () => _fetchItems(categoryId: categoryId),
      _menuInterval,
      const <MenuItem>[],
    );
  }

  Stream<List<MenuItem>> featuredItemsStream() {
    if (kDemoMode) {
      return Stream.value(DemoStore.items.where((i) => i.isAvailable).take(6).toList());
    }
    return _poll<List<MenuItem>>(
      'featured:${_branchId ?? 'all'}',
      () async {
        final items = await _fetchItems();
        return items.where((i) => i.isAvailable).take(10).toList();
      },
      _menuInterval,
      const <MenuItem>[],
    );
  }

  Future<List<MenuItem>> _fetchItems({String? categoryId}) async {
    // Sent only once a branch has been chosen. Leaving it off returns the
    // whole menu, which is what the pre-branch version of this app did --
    // so an old build keeps working against the new backend.
    final branchId = _branchId;
    final query = (branchId == null || branchId.isEmpty) ? '' : '?branchId=$branchId';
    final list = (await _get('/menu/items$query') as List?) ?? const [];
    final items = list
        .map((m) => MenuItem.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
        .where((i) => categoryId == null || i.categoryId == categoryId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  // ---------- Offers (home-page promo carousel) ----------
  Stream<List<OfferModel>> offersStream() {
    if (kDemoMode) return Stream.value(const []);
    return _poll<List<OfferModel>>(
      'offers',
      () async {
        // /offers/active returns only active offers, already sorted.
        final list = (await _get('/offers/active') as List?) ?? const [];
        return list
            .map((m) => OfferModel.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
            .toList();
      },
      _menuInterval,
      const <OfferModel>[],
    );
  }

  // ---------- Reviews ----------
  Stream<List<Review>> reviewsStream() {
    if (kDemoMode) return DemoStore.reviewsStream();
    return _poll<List<Review>>(
      'reviews',
      () async {
        final list = (await _get('/reviews') as List?) ?? const [];
        return list
            .map((m) => Review.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
            .toList();
      },
      _menuInterval,
      const <Review>[],
    );
  }

  Future<void> addReview({
    required String customerName,
    required double rating,
    required String comment,
  }) async {
    if (kDemoMode) {
      DemoStore.addReview(customerName, rating, comment);
      return;
    }
    await _send('POST', '/reviews', {
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
    });
  }

  // ---------- Enquiries ----------
  Future<void> submitEnquiry({
    required String name,
    required String phone,
    required String message,
  }) async {
    if (kDemoMode) {
      DemoStore.addEnquiry(name, phone, message);
      return;
    }
    await _send('POST', '/enquiries', {
      'customerName': name,
      'customerPhone': phone,
      'message': message,
    });
  }

  // ---------- Orders ----------
  // Placing a NEW order goes through OrderApiService (order_api_service.dart)
  // so the backend can send the shop's "new order" push in the same
  // request. Reading an order's live status and setting a payment method
  // are customer-authenticated calls scoped to that customer's own
  // orders -- the backend refuses an order belonging to anyone else.

  Stream<OrderModel?> orderStream(String orderId) {
    if (kDemoMode) return DemoStore.orderStream(orderId);
    return _poll<OrderModel?>(
      'order:$orderId',
      () async {
        final data = await _get('/account/orders/$orderId', auth: true);
        if (data == null) return null;
        final map = Map<String, dynamic>.from(data);
        return OrderModel.fromMap(map['id'] as String, map);
      },
      _orderInterval,
      null,
    );
  }

  Future<void> setPaymentMethod(String orderId, String method) async {
    if (kDemoMode) {
      DemoStore.setPaymentMethod(orderId, method);
      return;
    }
    await _send('PATCH', '/account/orders/$orderId/payment', {
      'paymentMethod': method,
      if (method == 'gpay') 'paymentConfirmedByCustomer': true,
    }, auth: true);
  }

  // ---------- User profile ----------
  Future<Map<String, dynamic>?> getMyProfile() async {
    final data = await _get('/account/me', auth: true);
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
  }) async {
    if (kDemoMode) {
      DemoStore.saveUserProfile(uid, name, phone, email);
      return;
    }
    // Email is set at registration and is the login identifier, so only
    // the editable fields are sent.
    await _send('PATCH', '/account/me', {'name': name, 'phone': phone}, auth: true);
  }

  Stream<AppUser?> userProfileStream(String uid) {
    if (kDemoMode) return DemoStore.userProfileStream(uid);
    return _poll<AppUser?>(
      'profile',
      () async {
        final data = await getMyProfile();
        return data == null ? null : AppUser.fromMap(uid, data);
      },
      _myOrdersInterval,
      null,
    );
  }

  // ---------- My orders (the signed-in customer's own history) ----------
  Future<List<OrderModel>> myOrders() async {
    final list = (await _get('/account/orders', auth: true) as List?) ?? const [];
    return list
        .map((m) => OrderModel.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
        .toList();
  }

  Stream<List<OrderModel>> myOrdersStream(String uid) {
    if (kDemoMode) return DemoStore.myOrdersStream(uid);
    return _poll<List<OrderModel>>('myorders', myOrders, _myOrdersInterval, const <OrderModel>[]);
  }
}

/// Kept so existing screens compile unchanged: they construct
/// `FirestoreService()` in a dozen places. It is now a thin alias for the
/// HTTP-backed [ApiService] — nothing here touches Firestore any more.
class FirestoreService {
  ApiService get _api => ApiService.instance;

  Stream<ShopSettings> shopSettingsStream({String? branchId}) =>
      _api.shopSettingsStream(branchId: branchId);
  Stream<List<CategoryModel>> categoriesStream() => _api.categoriesStream();
  Stream<List<MenuItem>> menuItemsStream({String? categoryId}) =>
      _api.menuItemsStream(categoryId: categoryId);
  Stream<List<MenuItem>> featuredItemsStream() => _api.featuredItemsStream();
  Stream<List<OfferModel>> offersStream() => _api.offersStream();
  Stream<List<Review>> reviewsStream() => _api.reviewsStream();
  Future<void> addReview({
    required String customerName,
    required double rating,
    required String comment,
  }) =>
      _api.addReview(customerName: customerName, rating: rating, comment: comment);
  Future<void> submitEnquiry({
    required String name,
    required String phone,
    required String message,
  }) =>
      _api.submitEnquiry(name: name, phone: phone, message: message);
  Stream<OrderModel?> orderStream(String orderId) => _api.orderStream(orderId);
  Future<void> setPaymentMethod(String orderId, String method) =>
      _api.setPaymentMethod(orderId, method);
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
  }) =>
      _api.saveUserProfile(uid: uid, name: name, phone: phone, email: email);
  Stream<AppUser?> userProfileStream(String uid) => _api.userProfileStream(uid);
  Stream<List<OrderModel>> myOrdersStream(String uid) => _api.myOrdersStream(uid);
}
