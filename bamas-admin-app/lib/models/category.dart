/// A menu category (e.g. "Burgers", "Drinks") used to group items. Shown
/// as a dropdown in the "Add menu item" screen so a new item can be filed
/// under the right category on the customer-facing `bamas` app, and
/// listed (with an "Add category" button) on the admin app's own
/// Categories screen.
class Category {
  final String id;
  final String name;
  final String imageUrl;

  /// false = hidden from the customer app, but kept along with its items
  /// so it can be switched back on. Categories created before this flag
  /// existed arrive without it, and are treated as live.
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        imageUrl: (json['imageUrl'] ?? '').toString(),
        isActive: json['isActive'] ?? true,
      );
}
