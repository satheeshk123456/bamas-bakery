"""
One shared Firebase Admin SDK connection, reused by every router.

Since the move to MongoDB (AWS EC2), this only uses Firebase for two
things: verifying/creating customer accounts (Firebase Authentication)
and sending FCM push notifications -- all app DATA (orders, menu,
offers, etc) now lives in MongoDB, see mongo_client.py. Firebase Auth
stays because it's free, already built, and MongoDB has no equivalent.
"""
import json

import firebase_admin
from firebase_admin import credentials, messaging

from .config import settings

_app = None


def get_firebase_app():
    global _app
    if _app is None:
        if settings.firebase_service_account_json:
            # Deployed: key JSON comes from an env var, not a file on disk.
            raw = settings.firebase_service_account_json
            try:
                cred_dict = json.loads(raw)
            except Exception as e:
                print(
                    f"[firebase] FAILED to parse FIREBASE_SERVICE_ACCOUNT_JSON "
                    f"(len={len(raw)}, starts={raw[:20]!r}, ends={raw[-20:]!r}): {e}"
                )
                raise
            print(
                f"[firebase] using env-var credentials -> "
                f"project_id={cred_dict.get('project_id')!r}, "
                f"client_email={cred_dict.get('client_email')!r}"
            )
            cred = credentials.Certificate(cred_dict)
        else:
            # Local dev: key JSON is a file next to this backend.
            print(
                "[firebase] FIREBASE_SERVICE_ACCOUNT_JSON is empty/not set -- "
                f"falling back to local file at {settings.firebase_service_account_path!r}"
            )
            cred = credentials.Certificate(settings.firebase_service_account_path)
        _app = firebase_admin.initialize_app(cred)
        print(f"[firebase] app initialized, project_id={_app.project_id!r}")
    return _app


def get_messaging():
    get_firebase_app()
    return messaging
