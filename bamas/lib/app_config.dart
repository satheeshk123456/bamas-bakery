/// DEMO MODE
///
/// true  -> the app runs with built-in fake data. Firebase is never
///          contacted, so you can run `flutter run -d chrome` right now
///          and click through every screen before doing any setup.
/// false -> the app talks to your real Firebase project. Flip this to
///          false once you've run `flutterfire configure` (see
///          docs/SETUP_GUIDE.md).
///
/// Set to false: firebase_options.dart now has real keys for the
/// "bamas" Firebase project (bamas-13c73).
const bool kDemoMode = false;

/// Base URL of the bamas-admin-backend server — the SAME backend the
/// admin app talks to. Used only for placing a new order (so the "new
/// order" push notification can be sent server-side without needing
/// Firebase's paid Blaze plan). Everything else — menu, live order
/// status — still reads Firestore directly.
///
/// Set this to the same URL used for kApiBaseUrl in the admin app
/// (bamas-admin-app/lib/app_config.dart), e.g. your Vercel deployment.
const String kApiBaseUrl = 'https://bamas-admin-backend.vercel.app';
