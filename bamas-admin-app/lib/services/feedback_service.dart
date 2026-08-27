import '../app_config.dart';
import '../models/enquiry.dart';
import '../models/review.dart';
import 'api_client.dart';

/// Everything customers submit that isn't an order: the Enquiry
/// ("contact us") form and star-rating reviews. Both used to be written
/// straight to Firestore with no way for the admin to ever see them.
class FeedbackService {
  Future<List<Enquiry>> listEnquiries() async {
    if (kDemoMode) return [];
    final result = await apiClient.get('/enquiries');
    return (result as List).map((e) => Enquiry.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> markEnquiryHandled(String id, bool handled) async {
    if (kDemoMode) return;
    await apiClient.patch('/enquiries/$id', body: {'handled': handled});
  }

  Future<List<AdminReview>> listReviews() async {
    if (kDemoMode) return [];
    final result = await apiClient.get('/reviews');
    return (result as List).map((e) => AdminReview.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> deleteReview(String id) async {
    if (kDemoMode) return;
    await apiClient.delete('/reviews/$id');
  }
}

final feedbackService = FeedbackService();
