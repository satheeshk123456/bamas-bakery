import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.values.fold(0, (sum, e) => sum + e.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, e) => sum + e.lineTotal);

  void addItem(MenuItem item) {
    if (_items.containsKey(item.id)) {
      _items[item.id]!.quantity += 1;
    } else {
      _items[item.id] = CartItem(item: item);
    }
    notifyListeners();
  }

  void removeOne(String itemId) {
    if (!_items.containsKey(itemId)) return;
    if (_items[itemId]!.quantity > 1) {
      _items[itemId]!.quantity -= 1;
    } else {
      _items.remove(itemId);
    }
    notifyListeners();
  }

  void deleteItem(String itemId) {
    _items.remove(itemId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toOrderItems() =>
      _items.values.map((e) => e.toOrderMap()).toList();
}
