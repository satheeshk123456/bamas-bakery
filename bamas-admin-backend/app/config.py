import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    # Firebase is used ONLY for FCM push notifications now -- identity
    # (admin and customer) is handled by this backend's own JWTs.
    firebase_service_account_path: str = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_PATH", "./serviceAccountKey.json"
    )
    # On Vercel there's no local serviceAccountKey.json file to point at
    # (it's gitignored, so it never gets deployed). Instead, paste the
    # WHOLE content of that JSON key file into a Vercel environment
    # variable named FIREBASE_SERVICE_ACCOUNT_JSON. When this is set,
    # firebase_client.py uses it instead of the file path above.
    firebase_service_account_json: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    # Long random secret used ONLY by the weekly automated backup job
    # (see routers/backup.py) -- deliberately separate from the real
    # admin login so a leaked backup key can only read a data export,
    # nothing else.
    backup_secret_key: str = os.getenv("BACKUP_SECRET_KEY", "")
    # MongoDB (AWS EC2) -- replaces Firestore for all data. Full URI
    # including the scoped app user's credentials, e.g.
    # mongodb://appuser:PASSWORD@127.0.0.1:27017/food_order_db?authSource=food_order_db
    mongo_uri: str = os.getenv("MONGO_URI", "")
    mongo_db_name: str = os.getenv("MONGO_DB_NAME", "food_order_db")
    # S3 (AWS) -- replaces base64-in-Firestore for images.
    aws_access_key_id: str = os.getenv("AWS_ACCESS_KEY_ID", "")
    aws_secret_access_key: str = os.getenv("AWS_SECRET_ACCESS_KEY", "")
    aws_region: str = os.getenv("AWS_REGION", "ap-southeast-2")
    s3_bucket_name: str = os.getenv("S3_BUCKET_NAME", "")
    admin_username: str = os.getenv("ADMIN_USERNAME", "admin")
    admin_password_hash: str = os.getenv("ADMIN_PASSWORD_HASH", "")
    jwt_secret: str = os.getenv("JWT_SECRET", "change-me")
    # Admin sessions stay short (a shop tablet left unattended should not
    # hold an admin session forever). Customers stay signed in ~1 year so
    # they are never asked to log in again on their own phone.
    jwt_expires_minutes: int = int(os.getenv("JWT_EXPIRES_MINUTES", "720"))
    customer_jwt_expires_minutes: int = int(
        os.getenv("CUSTOMER_JWT_EXPIRES_MINUTES", str(365 * 24 * 60))
    )
    allowed_origins: list[str] = [
        o.strip() for o in os.getenv("ALLOWED_ORIGINS", "*").split(",")
    ]


settings = Settings()
