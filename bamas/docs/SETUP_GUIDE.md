# Bamas Burger — Setup Guide

## 0. Run it right now, with zero setup (demo mode)

The app ships with `kDemoMode = true` in `lib/app_config.dart`. In this
mode Firebase is never contacted — the app runs on built-in fake data so
you can click through every screen immediately:

```
flutter pub get
flutter run -d chrome        # or: flutter run   (on a device/emulator)
```

You can browse categories, add items to the cart, place an order, and
after ~6 seconds the demo auto-"accepts" it so you can see the GPay /
Cash-on-Delivery step. One item is marked unavailable so you can see the
SOLD OUT state.

When you're ready to connect the real backend, set `kDemoMode = false`
and follow the steps below.

---

This scaffold is fully wired to Firebase but ships with **placeholder keys**.
Follow these steps in order. None of them need AWS, a custom domain, or a
credit card beyond the free Firebase "Blaze" plan (which stays at $0/month
at your order volume — see note in step 5).

## 1. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project** → name it
   (e.g. "bamas-burger") → you can skip Google Analytics.
2. In the project, click **Build → Firestore Database → Create database**
   → start in **production mode** → pick a region close to your users
   (e.g. `asia-south1` for India).
3. **Build → Storage → Get started** → production mode → same region.
4. **Build → Authentication → Get started → Sign-in method → Email/Password
   → Enable.**

## 2. Connect the Flutter app to Firebase

Install the FlutterFire CLI once:

```
dart pub global activate flutterfire_cli
```

From the `bamas/` project root:

```
flutterfire configure
```

Pick your Firebase project, select **Android** (and iOS if you'll ever
need it). This automatically:
- overwrites `lib/firebase_options.dart` with your real project keys
- drops `google-services.json` into `android/app/`

That's it for the mobile app's Firebase connection — no manual key
copying needed.

Then:

```
flutter pub get
```

## 3. Deploy the security rules & indexes

Install the Firebase CLI once (needs Node.js): `npm install -g firebase-tools`
then `firebase login`.

From the `bamas/` project root:

```
firebase use --add        # pick your project, alias it "default"
firebase deploy --only firestore,storage
```

This pushes `firestore.rules`, `firestore.indexes.json` and `storage.rules`
— the permission model described in `docs/ARCHITECTURE.md`.

## 4. Create your admin login

1. Firebase console → **Authentication → Users → Add user** → enter the
   email/password your team will use to log into the admin website.
2. Copy the new user's **UID** (shown in the users table).
3. Firebase console → **Firestore Database → Start collection** → collection
   ID `admins` → document ID = that UID → add any field, e.g. `role: "owner"`.
   This is what the security rules check to allow admin writes.

Repeat step 3 for each additional staff member who should have admin access.

## 5. Deploy the Cloud Functions (order notifications)

Cloud Functions require the **Blaze (pay-as-you-go)** plan — Firebase will
prompt you to upgrade when you try to deploy. This just means attaching a
card; at ~50 orders/day you stay inside the free monthly quota
(2,000,000 function calls, plenty of FCM messages), so the bill is $0.
If you'd rather skip this for now, the app and admin panel work fine
without it — you just won't get push notifications, and the admin will
need to keep the Orders tab open to see new orders arrive live.

```
cd functions
npm install
cd ..
firebase deploy --only functions
```

## 6. Set up and deploy the admin website

```
cd admin-panel
npm install
cp .env.example .env
```

Open `.env` and fill in the six `VITE_FIREBASE_*` values from:
Firebase console → ⚙️ **Project settings → General → Your apps → Add app → Web**
(register a nameless web app if you haven't already — this doesn't
create anything visible to customers, it's just how the admin panel talks
to Firebase).

Test it locally:

```
npm run dev
```

Deploy it live (free, gives you a `https://<project-id>.web.app` URL —
no domain purchase needed):

```
npm run build
firebase deploy --only hosting
```

Whenever you fix a bug or change something in the admin panel, re-run
`npm run build && firebase deploy --only hosting` — the fix is live for
your client within seconds, no reinstall on their end.

## 7. Add your real menu & branding

Easiest path: open the deployed (or locally running) admin panel, log in,
and use **Menu → Add a menu item** / **Settings** to add your categories,
food photos, prices, shop logo and GPay QR code. This replaces the
placeholder images generated in `assets/images/` — those were only there
so the app isn't empty while you're testing the wiring.

`seed_data.json` at the project root lists the same placeholder content
in case you'd rather bulk-import via the Firestore console instead.

## 8. Build the Android APK

```
flutter build apk --release
```

The installable file is at
`build/app/outputs/flutter-apk/app-release.apk` — send this directly to
your client (WhatsApp, Drive link, etc.). They'll need to allow
"install from unknown sources" once, since it isn't from the Play Store.

**Important:** open `android/app/build.gradle.kts` and change the
`applicationId` from the default `com.example.bamas` to something
specific to this client (e.g. `com.bamasburger.app`) before your first
real release — Android treats the applicationId as the app's permanent
identity, and changing it later means users effectively get a "new" app.

## 9. The "push a fix live" workflow, concretely

- **Bug in the admin website** → fix the code in `admin-panel/src` →
  `npm run build && firebase deploy --only hosting` → live in seconds.
- **Bug in order-notification logic** → fix `functions/index.js` →
  `firebase deploy --only functions` → live in seconds.
- **Menu, prices, availability, shop open/closed, GPay QR** → these are
  never "code" — they're admin panel actions, so there's nothing to
  deploy at all; changes are live in the customer app the moment you
  save them.
- **Bug inside the Flutter app itself** (a screen, a calculation) → this
  genuinely needs a new APK build + the client reinstalling it, same as
  any Android app not published to the Play Store. If instant patching
  of the app itself matters to you, look at **Shorebird**
  (https://shorebird.dev) — it adds real code-push for Flutter apps on
  a free tier. Not wired in here since it's an extra account/tool, but
  it's a drop-in addition later.
