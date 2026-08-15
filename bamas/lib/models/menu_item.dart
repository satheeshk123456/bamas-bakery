class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  final bool isAvailable;
  final double rating;
  final int sortOrder;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.isAvailable = true,
    this.rating = 4.5,
    this.sortOrder = 0,
  });

  factory MenuItem.fromMap(String id, Map<String, dynamic> map) {
    return MenuItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      categoryId: map['categoryId'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      rating: (map['rating'] ?? 4.5).toDouble(),
      sortOrder: (map['sortOrder'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'categoryId': categoryId,
        'isAvailable': isAvailable,
        'rating': rating,
        'sortOrder': sortOrder,
      };
}
