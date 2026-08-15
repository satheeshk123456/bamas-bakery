/// Web build: no push notifications. Same API surface as the mobile
/// implementation so callers don't need to care which one they got.
class NotificationService {
  static Future<void> init() async {}
  static Future<String?> getToken() async => null;
}
