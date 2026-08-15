/// Push notifications are a mobile-only concern here.
///
/// `flutter_local_notifications` and `firebase_messaging` don't build for
/// web, so this file conditionally exports a no-op stub when compiling
/// for Chrome and the real implementation on Android/iOS. That's what
/// lets `flutter run -d chrome` work for previewing the UI.
export 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_mobile.dart';
