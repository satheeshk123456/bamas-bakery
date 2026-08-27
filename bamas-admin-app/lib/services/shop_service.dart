import 'dart:io';
import '../app_config.dart';
import '../models/shop_settings.dart';
import 'api_client.dart';

/// Everything the admin app's Settings screen needs: read/update the
/// shop's contact info and banner text, and upload its four photos
/// (logo, hero, GPay QR, weekend-offer). This is what makes the WhatsApp
/// contact number -- and everything else about the shop -- editable
/// live from the app instead of needing a seed.py edit + redeploy.
class ShopService {
  Future<AdminShopSettings> getSettings() async {
    if (kDemoMode) {
      return AdminShopSettings(
        isOpen: true,
        shopName: "Bama's Burger Box",
        contactPhone: '+917708704534',
        address: '',
        upiId: '',
        logoUrl: '',
        gpayQrUrl: '',
        heroImageUrl: '',
        heroHeadline: 'Your Burger Cravings, Sorted',
        heroTagline: 'Taste the Love, Feel the Quality',
        weekendOfferEnabled: false,
        weekendOfferText: '',
        weekendOfferImageUrl: '',
      );
    }
    final result = await apiClient.get('/shop-settings');
    return AdminShopSettings.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<AdminShopSettings> updateSettings(AdminShopSettings settings) async {
    if (kDemoMode) return settings;
    final result = await apiClient.patch('/shop-settings', body: settings.toUpdateJson());
    return AdminShopSettings.fromJson((result as Map).cast<String, dynamic>());
  }

  /// [field] must be one of: logoUrl, heroImageUrl, gpayQrUrl,
  /// weekendOfferImageUrl. Returns the data: URI the backend stored.
  Future<String> uploadImage(String field, File file) async {
    if (kDemoMode) return file.path;
    final result = await apiClient.uploadFile(
      '/shop-settings/image',
      file,
      fields: {'field': field},
    );
    if (result is Map && result[field] != null) return result[field].toString();
    throw Exception('Upload succeeded but no image URL was returned.');
  }
}

final shopService = ShopService();
