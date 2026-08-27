import 'dart:io';
import '../app_config.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import 'api_client.dart';
import 'demo_data.dart';

class MenuService {
  Future<List<MenuItem>> listItems() async {
    if (kDemoMode) return demoMenuItems();
    final result = await apiClient.get('/menu/items');
    return (result as List).map((e) => MenuItem.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// Categories to choose from when adding a new item (e.g. Burgers, Drinks).
  Future<List<Category>> listCategories() async {
    if (kDemoMode) return demoCategories();
    final result = await apiClient.get('/menu/categories');
    return (result as List).map((e) => Category.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// Adds a brand-new item to the menu from the "Add menu item" screen.
  /// This is what makes it show up on the customer-facing `bamas` app's
  /// Menu tab — same `menuItems` collection, no reinstall needed.
  Future<MenuItem> createItem({
    required String name,
    required String description,
    required double price,
    required String categoryId,
  }) async {
    if (kDemoMode) {
      return MenuItem(
        id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: description,
        price: price,
        isAvailable: true,
        categoryId: categoryId,
      );
    }
    final result = await apiClient.post('/menu/items', body: {
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
    });
    return MenuItem.fromJson((result as Map).cast<String, dynamic>());
  }

  /// Adds a brand-new category (e.g. "Beverages") -- this is what was
  /// missing before: the admin could add items but never a whole new
  /// category to put them in. [imageUrl] is optional; a photo can also
  /// be attached afterwards via [uploadCategoryImage].
  Future<Category> createCategory({required String name, String? imageUrl}) async {
    if (kDemoMode) {
      return Category(id: 'demo-cat-${DateTime.now().millisecondsSinceEpoch}', name: name, imageUrl: imageUrl ?? '');
    }
    final result = await apiClient.post('/menu/categories', body: {
      'name': name,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    return Category.fromJson((result as Map).cast<String, dynamic>());
  }

  /// Uploads a photo for [categoryId] and returns the data: URI the
  /// backend stored it as. In demo mode, returns the local file path so
  /// the picked image still previews on-screen.
  Future<String> uploadCategoryImage(String categoryId, File file) async {
    if (kDemoMode) return file.path;
    final result = await apiClient.uploadFile('/menu/categories/$categoryId/image', file);
    if (result is Map && result['imageUrl'] != null) return result['imageUrl'].toString();
    throw Exception('Upload succeeded but no imageUrl was returned.');
  }

  Future<void> setAvailability(String id, bool isAvailable) async {
    if (kDemoMode) return; // no-op in demo mode
    await apiClient.patch('/menu/items/$id', body: {'isAvailable': isAvailable});
  }

  /// Saves price + image + offer edits made in the menu editor screen.
  /// See bamas-admin-backend's expected PATCH /menu/items/{id} contract in
  /// this file's header comment / the admin app README.
  Future<MenuItem> updateItem(MenuItem item) async {
    if (kDemoMode) return item; // just echo it back so the UI updates
    final result = await apiClient.patch('/menu/items/${item.id}', body: item.toUpdateJson());
    if (result is Map) {
      return MenuItem.fromJson((result).cast<String, dynamic>());
    }
    return item;
  }

  /// Uploads a photo picked from the gallery for [itemId] and returns the
  /// URL the backend stored it at. In demo mode, returns the local file
  /// path so the picked image still previews on-screen.
  Future<String> uploadImage(String itemId, File file) async {
    if (kDemoMode) return file.path;
    final result = await apiClient.uploadFile('/menu/items/$itemId/image', file);
    if (result is Map && result['imageUrl'] != null) return result['imageUrl'].toString();
    throw Exception('Upload succeeded but no imageUrl was returned.');
  }
}

final menuService = MenuService();
