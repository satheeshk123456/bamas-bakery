# Bama's Burger Box — Server & Deployment Guide

Everything needed to run, change and troubleshoot this system.
Written so another developer (or another AI assistant) can pick it up cold.

Last updated: 2 September 2026

---

## 1. Architecture — what runs where

| Piece | Where it lives |
|---|---|
| Backend API | FastAPI (Python 3.14) on AWS EC2 `52.62.189.19`, port 80 via nginx |
| Database | MongoDB 7.0 on the **same** EC2 box, database `food_order_db` |
| Images | AWS S3 bucket `bamasandstore8s3` (ap-southeast-2, private) |
| Admin identity | This backend's own JWT (bcrypt password hash in `.env`) |
| Customer identity | This backend's own JWT (bcrypt hashes in MongoDB `users`) |
| Push notifications | **Firebase FCM — this is the ONLY thing Firebase does** |
| Customer app | Flutter, `bamas/` |
| Admin app | Flutter, `bamas-admin-app/` |

**There is no Firestore and no Firebase Auth anywhere.** Both apps depend on
only `firebase_core` + `firebase_messaging`. Android push notifications
cannot be done without FCM — that is why Firebase remains at all.

### How images work
The database never stores an image, only an S3 **object key** such as
`items/abc123-4f2a.jpg`. On every read the backend converts that key into a
short-lived signed URL. Values that are already `http(s)://...` (stock
photos) or `assets/...` (images bundled in the Flutter app) are passed
through untouched — see `presigned_url()` in `app/image_utils.py`.

### How S3 credentials work
There are **no AWS access keys anywhere**. The EC2 instance has an IAM role
attached (`bamasandstore8-ec2-role`, AmazonS3FullAccess) and boto3 picks up
temporary credentials automatically. `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` in `.env` are deliberately **left empty**.

---

## 2. Connecting to the server

```powershell
$key = "F:\my_project_git\techbachelor\Aws setup pem\bamasandstore8.pem"
$server = "ubuntu@52.62.189.19"
```

Run those two lines first in any new terminal — everything below reuses them.

```powershell
ssh -i $key $server            # interactive shell
```

**If SSH times out:** your home IP changed. The security group only allows
SSH from one address. Fix: AWS Console → EC2 → Instances → your instance →
Security tab → the `sg-...` link → Edit inbound rules → the port 22 row →
Source → **My IP** → Save rules. (HTTP still works during this, because
port 80 is open to everyone — so "website works but SSH doesn't" always
means this.)

Server paths:

```
/home/ubuntu/bamasandstore8/          <- the backend
├── app/                              <- application code
├── deploy/                           <- helper scripts
├── venv/                             <- python virtualenv
├── .env                              <- secrets (chmod 600)
└── serviceAccountKey.json            <- Firebase key, FCM only (chmod 600)
```

---

## 3. Deploying a code change  ← the everyday task

Edit the file locally, copy it up, restart. Two commands.

```powershell
scp -i $key "F:\my_project_git\bamas-bakery\bamas-admin-backend\app\routers\orders.py" "${server}:/home/ubuntu/bamasandstore8/app/routers/orders.py"
ssh -i $key $server "sudo systemctl restart bamasandstore8 && sleep 2 && systemctl is-active bamasandstore8"
```

The second command prints `active` when it worked.

**The remote path mirrors the local path** under `bamas-admin-backend/`.
`app/routers/menu.py` locally → `/home/ubuntu/bamasandstore8/app/routers/menu.py`.

Several files at once:

```powershell
cd F:\my_project_git\bamas-bakery\bamas-admin-backend
scp -i $key app\security.py app\models.py "${server}:/home/ubuntu/bamasandstore8/app/"
scp -i $key app\routers\account.py app\routers\menu.py "${server}:/home/ubuntu/bamasandstore8/app/routers/"
ssh -i $key $server "sudo systemctl restart bamasandstore8 && sleep 2 && systemctl is-active bamasandstore8"
```

**If you changed `requirements.txt`**, install before restarting:

```powershell
scp -i $key requirements.txt "${server}:/home/ubuntu/bamasandstore8/requirements.txt"
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/pip install -r requirements.txt && sudo systemctl restart bamasandstore8"
```

**Always run the self-check after deploying** (section 5).

---

## 4. Restart, status, logs

```powershell
# restart (use this after any code change)
ssh -i $key $server "sudo systemctl restart bamasandstore8 && sleep 2 && systemctl is-active bamasandstore8"

# status
ssh -i $key $server "systemctl status bamasandstore8 --no-pager"

# last 50 log lines - THE place to look when something is broken
ssh -i $key $server "journalctl -u bamasandstore8 -n 50 --no-pager"

# live logs (Ctrl+C to stop)
ssh -i $key $server "journalctl -u bamasandstore8 -f"

# stop / start
ssh -i $key $server "sudo systemctl stop bamasandstore8"
ssh -i $key $server "sudo systemctl start bamasandstore8"

# nginx (the public port 80 front door)
ssh -i $key $server "sudo nginx -t && sudo systemctl restart nginx"
```

The service is defined in `/etc/systemd/system/bamasandstore8.service`
(source kept at `bamas-admin-backend/deploy/bamasandstore8.service`).
It restarts automatically on crash and on server reboot.

If you edit the service file itself, run `sudo systemctl daemon-reload`
before restarting.

---

## 5. Helper scripts (in `deploy/`)

### selfcheck.py — run this first whenever anything seems wrong
```powershell
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/selfcheck.py"
```
Checks 9 things: env values, which Firebase key is installed, server clock,
whether Google still accepts the key, Firestore reachability, MongoDB, S3
read, S3 write, and the running API. It tells you *which* piece is broken
instead of leaving you guessing.

### seed.py — create a starter menu
```powershell
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/seed.py"                  # dry run
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/seed.py --write"          # add missing items
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/seed.py --write --reset"  # wipe menu, reseed
```
`--reset` only ever clears categories / menuItems / offers / shopSettings.
It never touches orders, users, reviews or enquiries. Re-running without
`--reset` will not duplicate anything (it matches on name).

### inspect_images.py — audit every image field
```powershell
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/inspect_images.py"
```
Lists which images are real S3 objects (and verifies they exist in the
bucket), which are external URLs, and which are blank.

### storage.py — check disk, MongoDB and S3 usage
```powershell
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/storage.py"
```
Shows how full the EC2 disk is, which directories are largest, the size of
every MongoDB collection, and total S3 usage by folder. Worth checking every
month or so — a full disk stops MongoDB from accepting writes, which looks
like the app breaking for no reason.

Quick one-liner version without the script:
```powershell
ssh -i $key $server "df -h / && sudo du -sh /var/lib/mongodb ~/bamasandstore8 2>/dev/null"
```

### migrate_firestore.py — one-time Firestore import (already done)
Kept for reference. Reads Firestore over **REST, not gRPC** — gRPC hangs on
this EC2 instance, which cost hours to diagnose. If you ever need it again:
```powershell
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/migrate_firestore.py"          # dry run
ssh -i $key $server "cd ~/bamasandstore8 && venv/bin/python -u deploy/migrate_firestore.py --write"
```

---

## 6. Environment variables

Live at `/home/ubuntu/bamasandstore8/.env` on the server. The local template
is `bamas-admin-backend/.env.production` (gitignored).

| Variable | Notes |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_PATH` | `/home/ubuntu/bamasandstore8/serviceAccountKey.json` — FCM only |
| `ADMIN_USERNAME` | admin login email |
| `ADMIN_PASSWORD_HASH` | bcrypt hash, **not** the password |
| `JWT_SECRET` | signs both admin and customer tokens |
| `BACKUP_SECRET_KEY` | for the automated backup endpoint |
| `MONGO_URI` | `mongodb://admin:...@127.0.0.1:27017/?authSource=admin` |
| `MONGO_DB_NAME` | `food_order_db` |
| `AWS_ACCESS_KEY_ID` | **intentionally empty** — IAM role supplies it |
| `AWS_SECRET_ACCESS_KEY` | **intentionally empty** — IAM role supplies it |
| `AWS_REGION` | `ap-southeast-2` |
| `S3_BUCKET_NAME` | `bamasandstore8s3` |
| `ALLOWED_ORIGINS` | `*` |

To change one: edit `.env.production` locally, then

```powershell
scp -i $key "F:\my_project_git\bamas-bakery\bamas-admin-backend\.env.production" "${server}:/home/ubuntu/bamasandstore8/.env"
ssh -i $key $server "chmod 600 ~/bamasandstore8/.env && sudo systemctl restart bamasandstore8"
```

**Generating a new admin password hash** (input is hidden, not saved to history):
```bash
ssh -i $key $server
~/bamasandstore8/venv/bin/python -c "import bcrypt,getpass; print(bcrypt.hashpw(getpass.getpass('New password: ').encode(), bcrypt.gensalt()).decode())"
```

---

## 7. Building the Flutter apps

```powershell
cd F:\my_project_git\bamas-bakery\bamas          # or bamas-admin-app
flutter clean
flutter pub get
flutter build apk --release
```
APK lands in `build\app\outputs\flutter-apk\app-release.apk`.

Both apps point at the backend via `lib/app_config.dart`:
```dart
const String kApiBaseUrl = 'http://52.62.189.19';
```

**Build one app at a time.** They share Gradle daemons; building both at
once causes `Timeout waiting to lock build logic queue`.

---

## 8. Troubleshooting — problems actually hit on this project

| Symptom | Cause & fix |
|---|---|
| SSH times out but `http://52.62.189.19/health` works | Home IP changed. Security group → port 22 → Source → **My IP** |
| `Timeout waiting to lock build logic queue` | Stale Gradle daemon. `cd android; .\gradlew.bat --stop`, kill `java` processes, delete `android\.gradle`, rebuild |
| Kotlin daemon crash / corrupted AAR transform | Windows Defender scanning Gradle's files mid-write. Add exclusions for `%USERPROFILE%\.gradle`, the Flutter SDK folder, and `F:\my_project_git` |
| `Failed building wheel for pydantic-core` | Server runs Python 3.14; pinned package too old for it. Bump the pin to a version with a 3.14 wheel (that is why `pydantic==2.13.5`, `pymongo==4.17.0`) |
| `invalid_grant: Invalid JWT Signature` | The Firebase service-account key is revoked/stale. Generate a new one: Firebase Console → Project settings → Service accounts → Generate new private key, copy to server as `serviceAccountKey.json`. Confirm with `selfcheck.py` (check 4) |
| Firestore reads hang forever | gRPC does not work on this instance. Use the REST API instead (see `migrate_firestore.py`) |
| Script appears to hang over ssh with no output | Python buffers output through a pipe. Run with `python -u` |
| Compass `connect ETIMEDOUT` | Don't open port 27017. Use Compass → Advanced → Proxy/SSH → SSH with Identity File (host `52.62.189.19`, user `ubuntu`, the `.pem`), and set the URI host to `localhost` |
| App shows no menu / cannot connect | Check `kApiBaseUrl`, then `selfcheck.py`, then `journalctl -u bamasandstore8 -n 50` |

---

## 9. KNOWN GAPS — read before calling this production

These are real and unresolved. Ordered by how much they matter.

### 9.1 The server IP is not permanent — HIGHEST RISK
`52.62.189.19` is a **dynamic** public IP, and it is hardcoded into both
apps. If the instance is ever stopped and started, AWS assigns a different
address and **every installed app breaks permanently** — fixable only by
shipping a Play Store update.

**Fix (5 minutes, free):** EC2 → Elastic IPs → Allocate → Associate with the
instance. Do this before publishing anything.

### 9.2 Backups: manual is done, automatic still needs repointing
The admin app's **Data Backup** screen now downloads everything as one
Excel file and can restore from it, and it nags once a week if no backup
has been taken from that phone. Endpoints:

| Endpoint | Auth | What it does |
|---|---|---|
| `GET /backup/excel` | admin JWT | whole database as one `.xlsx` |
| `GET /backup/excel/scheduled` | `X-Backup-Key` header | same file, for a cron job |
| `POST /backup/restore?confirm=REPLACE-ALL-DATA` | admin JWT | rebuilds the DB from that `.xlsx` |
| `GET /backup/full` | admin JWT | older JSON export, still there |

Why Excel restores cleanly: the workbook carries a hidden `_meta` sheet
recording each column's type and whether a collection's `_id` is an
ObjectId or a string, so every document goes back under its **original
id** — which is what keeps each order attached to the customer who
placed it. Restore parses the entire file before it writes anything, so
a wrong or damaged file returns 400 and the live data is untouched.
`openpyxl` is required (`requirements.txt`), so after deploying
`backup.py` run `venv/bin/pip install -r requirements.txt`.

Still open: the *automatic* weekly job points at the old Vercel URL with
a key that was never configured there, so it has been failing silently.
It just needs repointing at `http://52.62.189.19/backup/excel/scheduled`.

### 9.3 Traffic is unencrypted HTTP
Chosen deliberately for speed, but it means admin passwords, customer
passwords, and every order (name, phone, address) travel in clear text.
Google Play's Data Safety form must then declare "not encrypted in transit",
which is shown publicly on the listing.

**Fix (~15 min):** free subdomain at duckdns.org pointing to the IP, then
`sudo certbot --nginx -d yourname.duckdns.org`. Afterwards change
`kApiBaseUrl` to `https://...` and delete
`android/app/src/main/res/xml/network_security_config.xml` from both apps.

### 9.4 Secrets shared in chat need rotating
The Firebase service-account key and the MongoDB `admin` password were both
pasted into an AI chat transcript. Treat both as compromised:
- Firebase Console → Service accounts → generate a new key, delete the old
- `mongosh` → `use admin` → `db.changeUserPassword("admin", "...")`, then
  update `MONGO_URI` in `.env`

Also: the app connects to MongoDB as the `admin` superuser. A scoped user
with `readWrite` on `food_order_db` only would limit the blast radius if
`.env` ever leaked.

### 9.5 Smaller items
- No monitoring/alerting — if the server dies, you find out from a customer
- Password reset by email is unavailable (needs an email sender, e.g. AWS SES)
- `POST /orders` is public and takes `userId` from the request body, so a
  crafted request could place an order attributed to another user
- A test customer (`testcustomer@example.com`) exists in the database

---

## 10. Quick facts for whoever picks this up next

- Backend code: `bamas-admin-backend/app/` — FastAPI, one router per area
- Ids: MongoDB `ObjectId` everywhere **except** `shopSettings` (`_id` is the
  literal string `"main"`) and `users` (`_id` is the customer's uid)
- Admin and customer JWTs are signed with the same secret but carry a
  `typ` claim (`admin` / `customer`), and each dependency accepts only its
  own kind. **Do not remove that claim** — without it a customer's token
  would unlock the admin endpoints
- Customers can only read/modify their own orders; the ownership check is in
  `_my_order_or_404()` in `app/routers/account.py`
- The customer app has no live database connection any more. It polls the
  API: an order being tracked every 8s, menu content every 60s. See
  `bamas/lib/services/api_service.dart`
- `bamas/lib/services/api_service.dart` also exports a `FirestoreService`
  class — it is a **name-only alias** kept so the screens compile unchanged.
  Nothing in it touches Firestore
- `kDemoMode` in `app_config.dart` makes either app run on local fake data
  with no network at all — useful for UI work
