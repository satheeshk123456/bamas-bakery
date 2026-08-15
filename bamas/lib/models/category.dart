class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      sortOrder: (map['sortOrder'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
      };
}
