# Bamas Admin Backend (FastAPI)

This is the backend for the **Bamas Admin** Flutter app. It sits **next to**
the existing `bamas` (customer app) and Firebase project — it does **not**
replace Firebase. It's a REST API, written in FastAPI, that:

- Logs the admin in (its own username/password + JWT, separate from
  Firebase Auth).
- Reads and updates the **same** Firestore `orders`, `menuItems`,
  `categories`, `shopSettings` collections the customer app and the
  existing web admin panel already use — via the Firebase Admin SDK.
- Lets the admin app Accept / Reject / Complete an order. Writing the new
  status into Firestore is enough to trigger the **existing** Cloud
  Function (`bamas/functions/index.js`) that already notifies the
  customer automatically — nothing new needed there.
- New-order notifications to the admin app reuse the **existing** FCM
  topic `admin_orders` that the existing Cloud Function already publishes
  to on every new order — the admin app just subscribes to that topic (see
  the Flutter app's `notification_service.dart`). This backend doesn't
  duplicate that; `/orders/{id}/notify-test` is only there so you can
  manually re-trigger the push while testing.

## 1. The one key you need to give this backend

Firebase console → your bamas project → ⚙️ **Project settings → Service
accounts → Generate new private key**. This downloads a JSON file.

Save it as `serviceAccountKey.json` in this folder (`bamas-admin-backend/`).
**Never commit it** — it's already in `.gitignore`.

This single key is what lets the backend read/write orders & menu items
and send push notifications — no other key needed for the backend itself.

## 2. Set up your admin login

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
python make_admin_password.py "choose-a-real-password"
```

Paste the printed hash into `.env` as `ADMIN_PASSWORD_HASH=...`. Also set
`JWT_SECRET` to a random string (the command to generate one is in
`.env.example`). Pick whatever `ADMIN_USERNAME` you want.

## 3. Run it

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Interactive API docs (test every endpoint from the browser): open
`http://localhost:8000/docs`.

Because the Flutter admin app runs on your **phone**, not your computer,
`localhost` on the phone is the phone itself, not your PC. While testing:

- **Android emulator** → use `http://10.0.2.2:8000` as the base URL.
- **Real phone on the same Wi-Fi as your PC** → use your PC's LAN IP,
  e.g. `http://192.168.1.23:8000` (find it with `ipconfig` on Windows).
  The admin app's `lib/services/api_config.dart` is where you set this.

For anything beyond local testing (so the admin app works from anywhere,
not just your home Wi-Fi), deploy this FastAPI app to a free host like
Render or Railway later — nothing in the code needs to change, just point
`api_config.dart` at the deployed URL.

## 4. Endpoints

All routes except `/health` and `/auth/login` require
`Authorization: Bearer <token>` from `/auth/login`.

- `POST /auth/login` `{username, password}` → `{access_token}`
- `GET /orders?status=pending` → list orders (newest first)
- `GET /orders/{id}` → one order
- `PATCH /orders/{id}/status` `{status: "accepted"|"rejected"|"completed"}`
- `POST /orders/{id}/notify-test` → re-send the admin push for that order
- `GET /menu/categories`
- `GET /menu/items?categoryId=...`
- `PATCH /menu/items/{id}` `{isAvailable?, price?, name?, description?}`
- `GET /shop-settings`
- `PATCH /shop-settings` `{isOpen}`

## Folder map

```
app/
  main.py            FastAPI app, CORS, router registration
  config.py           Reads .env
  firebase_client.py   Shared Firebase Admin SDK connection
  security.py          JWT + bcrypt password verification
  models.py             Request/response schemas
  routers/
    auth.py, orders.py, menu.py, shop.py
requirements.txt
.env.example
make_admin_password.py   Run once to generate ADMIN_PASSWORD_HASH
```
