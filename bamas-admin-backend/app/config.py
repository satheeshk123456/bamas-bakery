import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    firebase_service_account_path: str = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_PATH", "./serviceAccountKey.json"
    )
    # On Vercel there's no local serviceAccountKey.json file to point at
    # (it's gitignored, so it never gets deployed). Instead, paste the
    # WHOLE content of that JSON key file into a Vercel environment
    # variable named FIREBASE_SERVICE_ACCOUNT_JSON. When this is set,
    # firebase_client.py uses it instead of the file path above.
    firebase_service_account_json: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    # Firebase console -> Project settings -> General -> "Web API Key".
    # NOT the service-account key -- this one is used to verify a
    # customer's password via Google's Identity Toolkit REST API, since
    # the Admin SDK deliberately has no "check this password" call.
    firebase_web_api_key: str = os.getenv("FIREBASE_WEB_API_KEY", "")
    admin_username: str = os.getenv("ADMIN_USERNAME", "admin")
    admin_password_hash: str = os.getenv("ADMIN_PASSWORD_HASH", "")
    jwt_secret: str = os.getenv("JWT_SECRET", "change-me")
    jwt_expires_minutes: int = int(os.getenv("JWT_EXPIRES_MINUTES", "720"))
    allowed_origins: list[str] = [
        o.strip() for o in os.getenv("ALLOWED_ORIGINS", "*").split(",")
    ]


settings = Settings()
