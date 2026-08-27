import 'dart:io';
import '../app_config.dart';
import '../models/offer.dart';
import 'api_client.dart';

/// Home-page promo banners (the carousel on the customer app). Full
/// CRUD from the admin app, no reinstall needed on either side -- the
/// customer app reads the SAME Firestore `offers` collection live.
class OfferService {
  Future<List<Offer>> listOffers() async {
    if (kDemoMode) return [];
    final result = await apiClient.get('/offers');
    return (result as List).map((e) => Offer.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Offer> createOffer({required String title, String subtitle = '', bool isActive = true}) async {
    if (kDemoMode) {
      return Offer(
        id: 'demo-offer-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        subtitle: subtitle,
        imageUrl: '',
        isActive: isActive,
        sortOrder: 0,
      );
    }
    final result = await apiClient.post('/offers', body: {
      'title': title,
      'subtitle': subtitle,
      'isActive': isActive,
    });
    return Offer.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<Offer> setActive(String id, bool isActive) async {
    if (kDemoMode) throw UnimplementedError();
    final result = await apiClient.patch('/offers/$id', body: {'isActive': isActive});
    return Offer.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<String> uploadImage(String offerId, File file) async {
    if (kDemoMode) return file.path;
    final result = await apiClient.uploadFile('/offers/$offerId/image', file);
    if (result is Map && result['imageUrl'] != null) return result['imageUrl'].toString();
    throw Exception('Upload succeeded but no imageUrl was returned.');
  }

  Future<void> deleteOffer(String id) async {
    if (kDemoMode) return;
    await apiClient.delete('/offers/$id');
  }
}

final offerService = OfferService();
