import 'dart:io';
import '../app_config.dart';
import '../models/menu_item.dart';
import 'api_client.dart';
import 'demo_data.dart';

class MenuService {
  Future<List<MenuItem>> listItems() async {
    if (kDemoMode) return demoMenuItems();
    final result = await apiClient.get('/menu/items');
    return (result as List).map((e) => MenuItem.fromJson((e as Map).cast<String, dynamic>())).toList();
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
