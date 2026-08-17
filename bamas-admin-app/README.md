# Bamas Admin (Flutter)

The admin mobile app: receive a notification the instant a customer places
an order, then Accept / Reject / Complete it, plus toggle menu items
sold-out. It's a separate app/APK from the customer `bamas` app — install
both on the same phone or tablet if you like, they won't conflict.

It talks to **bamas-admin-backend** (the new FastAPI server, in the
folder next to this one) for everything — orders, menu — and gets its
push notifications straight from Firebase Cloud Messaging, reusing the
exact same "new order" push the existing Cloud Function already sends
(see `bamas/docs/ARCHITECTURE.md` and `bamas/functions/index.js`).

## 0. Try it right now, zero setup (demo mode)

Ships with `kDemoMode = true` in `lib/app_config.dart`. In this mode it
never contacts the backend or Firebase — you can log in with anything and
click through sample orders and the menu-availability screen immediately:

```
flutter pub get
flutter run
```

## 1. Set up the backend first

Follow `../bamas-admin-backend/README.md` — it needs one key (a Firebase
service-account JSON) and an admin username/password you choose.

## 2. Point this app at the backend

Open `lib/app_config.dart` and set `kApiBaseUrl` (see the comments there
for emulator vs. real-phone vs. deployed-server URLs), then set
`kDemoMode = false`.

## 3. Wire up push notifications (Firebase)

This app needs to be registered as a second Android app inside the
**same** Firebase project the customer app already uses (so it can
receive the `admin_orders` topic messages the existing Cloud Function
sends):

```
dart pub global activate flutterfire_cli
```

From this project's root (`bamas admin/`):

```
flutterfire configure
```

Pick the **same** Firebase project as the `bamas` customer app, select
**Android**. This overwrites `lib/firebase_options.dart` with real keys
and drops `google-services.json` into `android/app/`. If it asks for a
package name / applicationId, use `com.bamasburgerbox.admin` (already set
in `android/app/build.gradle.kts`).

Then:

```
flutter pub get
```

## 4. Build the APK

```
flutter build apk --release
```

Installable file: `build/app/outputs/flutter-apk/app-release.apk`. Send
it to whoever manages orders the same way you'd send the customer APK
(WhatsApp, Drive link) — "install from unknown sources" needs to be
allowed once, same as any non-Play-Store app.

## Folder map

```
lib/
  app_config.dart        Demo-mode flag + backend URL
  app_theme.dart          Branding (same palette as the customer app)
  firebase_options.dart   Placeholder -> replaced by `flutterfire configure`
  main.dart
  models/                 Order, MenuItem
  services/
    api_client.dart        Talks to bamas-admin-backend, stores the JWT
    auth_service.dart        Login/logout
    order_service.dart        Orders: list / get / accept / reject / complete
    menu_service.dart          Menu: list / toggle availability
    notification_service.dart   Subscribes to the "admin_orders" FCM topic
    demo_data.dart               Sample data for kDemoMode
  screens/
    splash_screen.dart, login_screen.dart, orders_screen.dart,
    order_detail_screen.dart, menu_availability_screen.dart
assets/images/logo.png    Same logo as the customer app
android/                  Android platform files (applicationId: com.bamasburgerbox.admin)
```

## What each "key" is, in one place

1. **Firebase service-account JSON** → goes in `bamas-admin-backend/serviceAccountKey.json`.
   Lets the backend read/write orders & menu and send pushes.
2. **This app's `google-services.json` + `firebase_options.dart`** → generated
   automatically by `flutterfire configure` in step 3 above, from the same
   Firebase project. Only used for receiving push notifications.
3. **Admin username/password** → you choose these; hash them with
   `bamas-admin-backend/make_admin_password.py` and put them in that
   folder's `.env`.

No other keys are needed for local development.

## Menu editor: photo, rate & offers (backend contract needed)

The Menu tab (`lib/screens/menu_availability_screen.dart` +
`lib/screens/menu_edit_screen.dart`) now lets you manually edit, per item:
a photo (picked from the gallery), the price ("rate"), and an offer
(percent off, flat ₹ off, and/or a short label like "Combo Deal"). These
changes are meant to flow through to the customer `bamas` app the same
way availability toggles already do.

This works fully in demo mode (`kDemoMode = true`) with no backend. To go
live, **`bamas-admin-backend` needs two things added** that don't exist
yet (as of this app's current API calls):

1. `POST /menu/items/{id}/image` — multipart file upload (field name
   `file`). Store the image (Firebase Storage, S3, or local static
   folder) and respond with `{"imageUrl": "https://..."}`.
2. `PATCH /menu/items/{id}` — already exists for `isAvailable`, needs to
   also accept these optional fields (any subset; a field explicitly set
   to `null` means "clear it"):
   ```json
   {
     "price": 120.0,
     "imageUrl": "https://.../burger.jpg",
     "discountPercent": 15.0,
     "discountAmount": null,
     "offerLabel": "Combo Deal"
   }
   ```
   The response should be the updated menu item (same shape as
   `GET /menu/items`), now including `imageUrl`, `discountPercent`,
   `discountAmount`, and `offerLabel`.

Whatever data source the `bamas` customer app reads its menu from (same
Firestore/DB the FastAPI backend writes to) should pick up these same
fields so a saved edit here shows up there — that's the "connect with
bamas APK" part. See `bamas/docs/ARCHITECTURE.md` for how the customer
app currently reads the menu.
