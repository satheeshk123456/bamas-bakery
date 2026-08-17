import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    firebase_service_account_path: str = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_PATH", "./serviceAccountKey.json"
    )
    admin_username: str = os.getenv("ADMIN_USERNAME", "admin")
    admin_password_hash: str = os.getenv("ADMIN_PASSWORD_HASH", "")
    jwt_secret: str = os.getenv("JWT_SECRET", "change-me")
    jwt_expires_minutes: int = int(os.getenv("JWT_EXPIRES_MINUTES", "720"))
    allowed_origins: list[str] = [
        o.strip() for o in os.getenv("ALLOWED_ORIGINS", "*").split(",")
    ]


settings = Settings()
