from fastapi import APIRouter, Depends, HTTPException
import httpx
from firebase_admin import auth as fb_auth, firestore

from ..config import settings
from ..firebase_client import get_db, get_firebase_app
from ..models import (
    AuthTokenResponse,
    CustomerLoginRequest,
    CustomerRegisterRequest,
    ForgotPasswordRequest,
)
from ..security import get_current_customer_uid

# Everything the bamas customer app needs for accounts: register, login,
# forgot-password, "my profile", "my orders". Deliberately a SEPARATE
# router/prefix from auth.py (that one is the shop admin's own
# username+password login) and from orders.py's /orders/{order_id}
# (an /orders/mine path would collide with that dynamic route).
router = APIRouter(prefix="/account", tags=["account"])

IDENTITY_TOOLKIT_BASE = "https://identitytoolkit.googleapis.com/v1/accounts"


def _require_web_api_key():
    if not settings.firebase_web_api_key:
        raise HTTPException(
            status_code=500,
            detail=(
                "Server is missing FIREBASE_WEB_API_KEY. Set it in the "
                "backend's environment variables (Firebase console -> "
                "Project settings -> General -> Web API Key)."
            ),
        )


@router.post("/register", response_model=AuthTokenResponse)
async def register(body: CustomerRegisterRequest):
    """Creates the Firebase Auth user AND the users/{uid} profile doc,
    server-side, using the Admin SDK -- the app never talks to Firebase
    Auth directly to sign someone up."""
    get_firebase_app()
    try:
        user = fb_auth.create_user(
            email=body.email.strip(),
            password=body.password,
            display_name=body.name.strip(),
        )
    except fb_auth.EmailAlreadyExistsError:
        raise HTTPException(status_code=409, detail="An account already exists for that email.")
    except ValueError as e:
        # Admin SDK raises ValueError for things like "password too short"
        # or a malformed email.
        raise HTTPException(status_code=400, detail=str(e))

    db = get_db()
    db.collection("users").document(user.uid).set(
        {
            "name": body.name.strip(),
            "phone": body.phone.strip(),
            "email": body.email.strip(),
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
    )

    token = fb_auth.create_custom_token(user.uid).decode("utf-8")
    return AuthTokenResponse(uid=user.uid, customToken=token)


@router.post("/login", response_model=AuthTokenResponse)
async def login(body: CustomerLoginRequest):
    """Checks the password via Google's Identity Toolkit REST API (the
    Admin SDK has no "verify this password" call), then mints a Firebase
    custom token for that uid so the app can establish a normal session."""
    _require_web_api_key()
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            f"{IDENTITY_TOOLKIT_BASE}:signInWithPassword",
            params={"key": settings.firebase_web_api_key},
            json={"email": body.email.strip(), "password": body.password, "returnSecureToken": True},
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Incorrect email or password.")

    uid = resp.json()["localId"]
    get_firebase_app()
    token = fb_auth.create_custom_token(uid).decode("utf-8")
    return AuthTokenResponse(uid=uid, customToken=token)


@router.post("/forgot-password")
async def forgot_password(body: ForgotPasswordRequest):
    _require_web_api_key()
    async with httpx.AsyncClient(timeout=10) as client:
        await client.post(
            f"{IDENTITY_TOOLKIT_BASE}:sendOobCode",
            params={"key": settings.firebase_web_api_key},
            json={"requestType": "PASSWORD_RESET", "email": body.email.strip()},
        )
    # Always report success, even if that email has no account -- so this
    # endpoint can't be used to check which emails are registered.
    return {"sent": True}


@router.get("/me")
def get_my_profile(uid: str = Depends(get_current_customer_uid)):
    db = get_db()
    doc_ref = db.collection("users").document(uid)
    doc = doc_ref.get()
    if not doc.exists:
        # Self-heal instead of 404ing forever: the caller has a valid
        # Firebase session token (get_current_customer_uid already
        # verified it), so the Auth user genuinely exists -- but their
        # users/{uid} profile doc is missing. This happens for accounts
        # created before /account/register started writing this doc, or
        # created directly in the Firebase console. Build a minimal
        # profile from the Auth record so the Account screen always has
        # something to show instead of a blank name.
        try:
            auth_user = fb_auth.get_user(uid)
        except Exception:
            auth_user = None
        doc_ref.set(
            {
                "name": (getattr(auth_user, "display_name", None) or "") if auth_user else "",
                "phone": "",
                "email": (getattr(auth_user, "email", None) or "") if auth_user else "",
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        doc = doc_ref.get()
    data = doc.to_dict() or {}
    data["uid"] = uid
    created = data.get("createdAt")
    if created is not None and hasattr(created, "isoformat"):
        data["createdAt"] = created.isoformat()
    return data


@router.get("/orders")
def get_my_orders(uid: str = Depends(get_current_customer_uid), limit: int = 50):
    db = get_db()
    query = (
        db.collection("orders")
        .where("userId", "==", uid)
        .order_by("createdAt", direction="DESCENDING")
        .limit(limit)
    )
    orders = []
    for doc in query.stream():
        data = doc.to_dict() or {}
        data["id"] = doc.id
        for key in ("createdAt", "updatedAt"):
            value = data.get(key)
            if value is not None and hasattr(value, "isoformat"):
                data[key] = value.isoformat()
        orders.append(data)
    return orders
