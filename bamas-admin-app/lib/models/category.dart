/// A menu category (e.g. "Burgers", "Drinks") used to group items. Shown
/// as a dropdown in the "Add menu item" screen so a new item can be filed
/// under the right category on the customer-facing `bamas` app, and
/// listed (with an "Add category" button) on the admin app's own
/// Categories screen.
class Category {
  final String id;
  final String name;
  final String imageUrl;

  Category({required this.id, required this.name, this.imageUrl = ''});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        imageUrl: (json['imageUrl'] ?? '').toString(),
      );
}
