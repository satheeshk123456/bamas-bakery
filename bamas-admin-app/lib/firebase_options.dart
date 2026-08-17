// PLACEHOLDER — replace this whole file by running `flutterfire configure`
// from this project's root (bamas admin/) and picking the SAME Firebase
// project the customer app (bamas/) already uses, selecting Android when
// asked which platforms. This registers a second Android app in that
// project (package: com.bamasburgerbox.admin) and overwrites this file
// with the real keys — no manual copying needed. See ../README.md.
//
// This app only uses Firebase for push notifications (FCM), so you do not
// need to touch Firestore/Storage/Auth setup again — that's already done
// for the bamas project.

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
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
  );
}
