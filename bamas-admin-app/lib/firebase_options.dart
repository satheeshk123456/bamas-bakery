// Real values for Android, copied from the "bamas" Firebase project
// (project bamas-13c73) via console.firebase.google.com ->
// com.bamasburgerbox.admin -> google-services.json. Same Firebase
// project as the customer app (bamas/), registered as a second Android
// app so this app can use FCM push notifications.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('This admin app targets Android only.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform - '
          'this admin app targets Android only.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD7LvfUbHf64lrReAuPt83wgpu4MYPETVA',
    appId: '1:594458332820:android:b999f9bf654d7ce4fc2e81',
    messagingSenderId: '594458332820',
    projectId: 'bamas-13c73',
    storageBucket: 'bamas-13c73.firebasestorage.app',
  );
}
