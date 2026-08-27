from datetime import datetime, timedelta, timezone

import bcrypt
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from firebase_admin import auth as fb_auth
from jose import JWTError, jwt

from .config import settings
from .firebase_client import get_firebase_app

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password:
        return False
    try:
        return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
    except (ValueError, TypeError):
        # ADMIN_PASSWORD_HASH in .env isn't a valid bcrypt hash yet (e.g.
        # still the placeholder) -- treat as "wrong password" rather than
        # crashing the request with a 500.
        return False


def hash_password(plain_password: str) -> str:
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def create_access_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expires_minutes)
    payload = {"sub": subject, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def get_current_customer_uid(authorization: str | None = Header(None)) -> str:
    """Verifies the Firebase ID token a signed-in customer sends as
    `Authorization: Bearer <idToken>`. This is completely separate from
    get_current_admin below -- customers authenticate via Firebase Auth
    (through /account/register and /account/login), shop admins via this
    backend's own username/password + JWT."""
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired session, please log in again.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not authorization or not authorization.lower().startswith("bearer "):
        raise unauthorized
    token = authorization.split(" ", 1)[1]
    get_firebase_app()  # make sure the Admin SDK is initialised before use
    try:
        decoded = fb_auth.verify_id_token(token)
    except Exception:
        raise unauthorized
    return decoded["uid"]


def get_current_admin(token: str = Depends(oauth2_scheme)) -> str:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired session, please log in again.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        username: str | None = payload.get("sub")
        if username is None:
            raise credentials_exception
        return username
    except JWTError:
        raise credentials_exception
