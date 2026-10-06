"""
One shared MongoDB connection, reused by every router. Replaces
Firestore as of the move to AWS EC2 -- the Firebase Admin SDK (see
firebase_client.py) is still used, but ONLY for Firebase Authentication
(customer register/login/ID-token verification) and FCM push
notifications, neither of which touch a database at all.
"""
from pymongo import MongoClient
from pymongo.database import Database

from .config import settings

_client: MongoClient | None = None


def get_mongo_client() -> MongoClient:
    global _client
    if _client is None:
        if not settings.mongo_uri:
            raise RuntimeError(
                "MONGO_URI is not set. Add it to the backend's .env / "
                "environment, e.g. "
                "mongodb://appuser:PASSWORD@127.0.0.1:27017/food_order_db?authSource=food_order_db"
            )
        _client = MongoClient(settings.mongo_uri, tz_aware=True)
    return _client


def get_db() -> Database:
    return get_mongo_client()[settings.mongo_db_name]
