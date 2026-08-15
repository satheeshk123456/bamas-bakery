# Bamas Burger

Customer ordering app (Flutter → APK) + admin website (React, Firebase
Hosting) + Firebase backend (Firestore, Storage, Cloud Functions, FCM).

**Start here → `docs/SETUP_GUIDE.md`** for step-by-step Firebase project
setup, connecting the app, deploying the admin panel, and building the
APK. `docs/ARCHITECTURE.md` explains the data model and order flow.

## Folder map

```
lib/                Flutter customer app source
assets/images/       Placeholder logo/food/QR images — replace via the admin panel
android/, ios/, web/... standard Flutter platform folders
functions/           Cloud Functions (order push notifications)
admin-panel/         React + Vite admin website (separate app, own package.json)
firebase.json, firestore.rules, firestore.indexes.json, storage.rules, .firebaserc
                      Firebase project config (shared by app + functions + hosting)
seed_data.json        Sample menu content, for reference / bulk import
docs/                 Setup guide + architecture notes
```
