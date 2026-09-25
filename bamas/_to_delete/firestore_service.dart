import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_config.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/offer.dart';
import '../models/app_user.dart';
import '../models/order_model.dart';
import '../models/review.dart';
import '../models/shop_settings.dart';
import 'demo_data.dart';

/// Every read/write to Firebase goes through this one class.
/// Screens never talk to Firestore directly — keeps the data layer
/// swappable and easy to debug.
///
/// When kDemoMode is true, every method below returns local fake data
/// instead and Firebase is never touched.
class FirestoreService {
  // Lazy on purpose: in demo mode Firebase is never initialised, so this
  // must not be evaluated at construction time.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---------- Shop settings (open/closed, logo, hero, GPay QR) ----------
  Stream<ShopSettings> shopSettingsStream() {
    if (kDemoMode) return Stream.value(DemoStore.settings);
    return _db
        .collection('shopSettings')
        .doc('main')
        .snapshots()
        .map((doc) => ShopSettings.fromMap(doc.data()));
  }

  // ---------- Categories ----------
  Stream<List<CategoryModel>> categoriesStream() {
    if (kDemoMode) return Stream.value(DemoStore.categories);
    return _db
        .collection('categories')
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CategoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ---------- Menu items ----------
  Stream<List<MenuItem>> menuItemsStream({String? categoryId}) {
    if (kDemoMode) {
      final items = categoryId == null
          ? DemoStore.items
          : DemoStore.items.where((i) => i.categoryId == categoryId).toList();
      return Stream.value(items);
    }
    Query<Map<String, dynamic>> query = _db.collection('menuItems');
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) => MenuItem.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  }

  Stream<List<MenuItem>> featuredItemsStream() {
    if (kDemoMode) {
      return Stream.value(
          DemoStore.items.where((i) => i.isAvailable).take(6).toList());
    }
    return _db
        .collection('menuItems')
        .where('isAvailable', isEqualTo: true)
        .limit(10)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MenuItem.fromMap(d.id, d.data())).toList());
  }

  // ---------- Offers (home-page promo carousel) ----------
  // Filtering to isActive happens client-side (not in the query) so this
  // stays a single-field orderBy -- no composite index needed, unlike
  // the orders queries that bit this project twice before.
  Stream<List<OfferModel>> offersStream() {
    if (kDemoMode) return Stream.value(const []);
    return _db
        .collection('offers')
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map((d) => OfferModel.fromMap(d.id, d.data())).toList());
  }

  // ---------- Reviews ----------
  Stream<List<Review>> reviewsStream() {
    if (kDemoMode) return DemoStore.reviewsStream();
    return _db
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Review.fromMap(d.id, d.data())).toList());
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
    await _db.collection('reviews').add({
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
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
    await _db.collection('enquiries').add({
      'name': name,
      'phone': phone,
      'message': message,
      'handled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Orders ----------
  // Placing a NEW order goes through OrderApiService (order_api_service.dart)
  // instead of straight to Firestore, so bamas-admin-backend can send the
  // "new order" push in the same request without needing Firebase's paid
  // Blaze plan. Everything below here — reading an order's live status,
  // and the customer picking a payment method — still talks to Firestore
  // directly, since those are just reads/writes the customer's own device
  // is allowed to do under the Firestore security rules.

  Stream<OrderModel?> orderStream(String orderId) {
    if (kDemoMode) return DemoStore.orderStream(orderId);
    return _db.collection('orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromMap(doc.id, doc.data()!);
    });
  }

  // ---------- User profiles ----------
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
    await _db.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<AppUser?> userProfileStream(String uid) {
    if (kDemoMode) return DemoStore.userProfileStream(uid);
    return _db.collection('users').doc(uid).snapshots().map(
        (doc) => doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null);
  }

  // ---------- My orders (the logged-in user's own order history) ----------
  Stream<List<OrderModel>> myOrdersStream(String uid) {
    if (kDemoMode) return DemoStore.myOrdersStream(uid);
    return _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> setPaymentMethod(String orderId, String method) async {
    if (kDemoMode) {
      DemoStore.setPaymentMethod(orderId, method);
      return;
    }
    return _db.collection('orders').doc(orderId).update({
      'paymentMethod': method,
      if (method == 'gpay') 'paymentConfirmedByCustomer': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
