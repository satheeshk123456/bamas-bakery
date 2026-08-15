import 'menu_item.dart';

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  double get lineTotal => item.price * quantity;

  Map<String, dynamic> toOrderMap() => {
        'itemId': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': quantity,
      };
}
