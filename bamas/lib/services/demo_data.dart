import 'dart:async';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/order_model.dart';
import '../models/review.dart';
import '../models/shop_settings.dart';

/// In-memory stand-in for Firestore, used only when kDemoMode == true.
/// Lets the whole app be clicked through — including placing an order and
/// watching it get "accepted" — with no backend at all.
///
/// Images point at bundled placeholder artwork in assets/images/. When the
/// client's real photos arrive they get uploaded through the admin panel
/// and become Storage URLs; nothing in the UI needs to change, because
/// AppImage handles both.
class DemoStore {
  static const _cBurgers = 'c1';
  static const _cSides = 'c2';
  static const _cDrinks = 'c3';
  static const _cCombos = 'c4';

  static final categories = [
    CategoryModel(
        id: _cBurgers,
        name: 'Burgers',
        imageUrl: 'assets/images/cat_burgers.png',
        sortOrder: 1),
    CategoryModel(
        id: _cSides,
        name: 'Sides',
        imageUrl: 'assets/images/cat_sides.png',
        sortOrder: 2),
    CategoryModel(
        id: _cDrinks,
        name: 'Drinks',
        imageUrl: 'assets/images/cat_drinks.png',
        sortOrder: 3),
    CategoryModel(
        id: _cCombos,
        name: 'Combos',
        imageUrl: 'assets/images/cat_combos.png',
        sortOrder: 4),
  ];

  static final items = [
    MenuItem(
      id: 'i1',
      name: 'Classic Veg Burger',
      description: 'Crispy veg patty, cheddar, lettuce, house sauce.',
      price: 90,
      imageUrl: 'assets/images/classic_burger.png',
      categoryId: _cBurgers,
      rating: 4.5,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i2',
      name: 'Spicy Chicken Burger',
      description: 'Crispy chicken fillet, spicy mayo, pickles.',
      price: 130,
      imageUrl: 'assets/images/chicken_burger.png',
      categoryId: _cBurgers,
      rating: 4.7,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i3',
      name: 'Double Cheese Burger',
      description: 'Two patties, double cheddar, smoky sauce.',
      price: 180,
      imageUrl: 'assets/images/double_burger.png',
      categoryId: _cBurgers,
      isAvailable: false, // shows the SOLD OUT overlay
      rating: 4.8,
      sortOrder: 3,
    ),
    MenuItem(
      id: 'i4',
      name: 'Paneer Tikka Burger',
      description: 'Grilled paneer, mint mayo, onions.',
      price: 120,
      imageUrl: 'assets/images/classic_burger.png',
      categoryId: _cBurgers,
      rating: 4.4,
      sortOrder: 4,
    ),
    MenuItem(
      id: 'i5',
      name: 'Peri Peri Fries',
      description: 'Crispy fries tossed in peri peri seasoning.',
      price: 80,
      imageUrl: 'assets/images/fries.png',
      categoryId: _cSides,
      rating: 4.4,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i6',
      name: 'Cheesy Nachos',
      description: 'Corn nachos with molten cheese dip.',
      price: 95,
      imageUrl: 'assets/images/nachos.png',
      categoryId: _cSides,
      rating: 4.3,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i7',
      name: 'Salted Fries',
      description: 'Golden, hot and lightly salted.',
      price: 60,
      imageUrl: 'assets/images/fries.png',
      categoryId: _cSides,
      rating: 4.2,
      sortOrder: 3,
    ),
    MenuItem(
      id: 'i8',
      name: 'Chilled Cola',
      description: 'Ice cold 300ml bottle.',
      price: 40,
      imageUrl: 'assets/images/coke.png',
      categoryId: _cDrinks,
      rating: 4.6,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i9',
      name: 'Chocolate Shake',
      description: 'Thick shake with chocolate syrup.',
      price: 110,
      imageUrl: 'assets/images/shake.png',
      categoryId: _cDrinks,
      rating: 4.7,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i10',
      name: 'Burger + Fries + Cola',
      description: 'The full meal, best value.',
      price: 210,
      imageUrl: 'assets/images/combo.png',
      categoryId: _cCombos,
      rating: 4.9,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i11',
      name: 'Family Box (4 Burgers)',
      description: 'Four burgers, two large fries, four colas.',
      price: 620,
      imageUrl: 'assets/images/combo.png',
      categoryId: _cCombos,
      rating: 4.8,
      sortOrder: 2,
    ),
  ];

  static final settings = ShopSettings(
    isOpen: true,
    shopName: "Bama's Burger Box",
    logoUrl: 'assets/images/logo.png',
    gpayQrUrl: 'assets/images/gpay_qr.png',
    upiId: 'bamasburgerbox@upi',
    contactPhone: '+91 90000 00000',
    heroImageUrl: 'assets/images/hero.png',
    heroHeadline: 'Your Burger Cravings, Sorted',
    heroTagline: 'Taste the Love, Feel the Quality',
    address: 'Main Road, Your Town — open 11am to 11pm',
  );

  // ---------- Reviews ----------
  static final List<Review> _reviews = [
    Review(
      id: 'r1',
      customerName: 'Praveen K.',
      rating: 5,
      comment: 'Best burgers in town. The spicy chicken one is unreal.',
    ),
    Review(
      id: 'r2',
      customerName: 'Divya S.',
      rating: 4,
      comment: 'Tasty and hot on delivery. Fries could be crispier.',
    ),
    Review(
      id: 'r3',
      customerName: 'Arun M.',
      rating: 5,
      comment: 'Ordered the combo, great value. Will order again!',
    ),
    Review(
      id: 'r4',
      customerName: 'Fathima R.',
      rating: 5,
      comment: 'Quick delivery and the packaging was neat. Loved it.',
    ),
  ];

  static final _reviewsController = StreamController<List<Review>>.broadcast();

  static Stream<List<Review>> reviewsStream() {
    Future.microtask(() => _reviewsController.add(List.of(_reviews)));
    return _reviewsController.stream;
  }

  static void addReview(String name, double rating, String comment) {
    _reviews.insert(
      0,
      Review(
        id: 'r${_reviews.length + 1}',
        customerName: name,
        rating: rating,
        comment: comment,
      ),
    );
    _reviewsController.add(List.of(_reviews));
  }

  // ---------- Enquiries ----------
  static final List<Enquiry> enquiries = [];

  static void addEnquiry(String name, String phone, String message) {
    enquiries.insert(
      0,
      Enquiry(
        id: 'e${enquiries.length + 1}',
        name: name,
        phone: phone,
        message: message,
      ),
    );
  }

  // ---------- Orders ----------
  static final Map<String, OrderModel> _orders = {};
  static final Map<String, StreamController<OrderModel?>> _controllers = {};
  static int _counter = 0;

  static String createOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String customerName,
    required String customerPhone,
    required String address,
  }) {
    _counter++;
    final id = 'demo${_counter.toString().padLeft(3, '0')}xyz';
    _orders[id] = OrderModel(
      id: id,
      items: items,
      totalAmount: totalAmount,
      customerName: customerName,
      customerPhone: customerPhone,
      location: OrderLocation(address: address),
      status: 'pending',
    );

    // Pretend the shop calls and accepts after 6 seconds, so you can see
    // the GPay / Cash-on-Delivery step without running an admin panel.
    Timer(const Duration(seconds: 6), () => _setStatus(id, 'accepted'));
    return id;
  }

  static void _setStatus(String id, String status) {
    final o = _orders[id];
    if (o == null) return;
    _orders[id] = OrderModel(
      id: o.id,
      items: o.items,
      totalAmount: o.totalAmount,
      customerName: o.customerName,
      customerPhone: o.customerPhone,
      location: o.location,
      status: status,
      paymentMethod: o.paymentMethod,
    );
    _controllers[id]?.add(_orders[id]);
  }

  static void setPaymentMethod(String id, String method) {
    final o = _orders[id];
    if (o == null) return;
    _orders[id] = OrderModel(
      id: o.id,
      items: o.items,
      totalAmount: o.totalAmount,
      customerName: o.customerName,
      customerPhone: o.customerPhone,
      location: o.location,
      status: o.status,
      paymentMethod: method,
      paymentConfirmedByCustomer: method == 'gpay',
    );
    _controllers[id]?.add(_orders[id]);
  }

  static Stream<OrderModel?> orderStream(String id) {
    final controller = _controllers.putIfAbsent(
        id, () => StreamController<OrderModel?>.broadcast());
    Future.microtask(() => controller.add(_orders[id]));
    return controller.stream;
  }

  static OrderModel? getOrder(String id) => _orders[id];
}
