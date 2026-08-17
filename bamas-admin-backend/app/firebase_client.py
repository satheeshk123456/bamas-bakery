"""
One shared Firebase Admin SDK connection, reused by every router.

Uses the SAME Firebase project as the existing `bamas` customer app and
`admin-panel` web app (see bamas/docs/ARCHITECTURE.md) — this backend does
not create a new database, it just reads/writes the existing Firestore
`orders`, `menuItems`, `categories`, `shopSettings` collections with
elevated (admin) privileges via the service-account key, and can send FCM
pushes the same way the existing Cloud Functions do.
"""
import firebase_admin
from firebase_admin import credentials, firestore, messaging

from .config import settings

_app = None


def get_firebase_app():
    global _app
    if _app is None:
        cred = credentials.Certificate(settings.firebase_service_account_path)
        _app = firebase_admin.initialize_app(cred)
    return _app


def get_db():
    get_firebase_app()
    return firestore.client()


def get_messaging():
    get_firebase_app()
    return messaging
