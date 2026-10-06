import re
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from ..mongo_client import get_db
from ..mongo_utils import serialize
from ..models import (
    AuthTokenResponse,
    CustomerLoginRequest,
    CustomerRegisterRequest,
    ForgotPasswordRequest,
    PaymentUpdate,
    ProfileUpdate,
)
from ..mongo_utils import oid
from ..security import (
    TOKEN_TYPE_CUSTOMER,
    create_access_token,
    get_current_customer_uid,
    hash_password,
    verify_password,
)

# Customer accounts, handled entirely by this backend: register, login,
# "my profile", "my orders". Passwords are bcrypt-hashed in MongoDB and
# sessions are this backend's own JWTs -- the same mechanism the shop
# admin login uses. Firebase is no longer involved in identity at all
# (it is kept only for FCM push notifications).
router = APIRouter(prefix="/account", tags=["account"])

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
MIN_PASSWORD_LEN = 6


def _clean_email(value: str) -> str:
    email = (value or "").strip().lower()
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="Please enter a valid email address.")
    return email


def _issue(uid: str) -> AuthTokenResponse:
    return AuthTokenResponse(uid=uid, accessToken=create_access_token(uid, TOKEN_TYPE_CUSTOMER))


@router.post("/register", response_model=AuthTokenResponse)
def register(body: CustomerRegisterRequest):
    email = _clean_email(body.email)
    if len(body.password or "") < MIN_PASSWORD_LEN:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least %d characters." % MIN_PASSWORD_LEN,
        )

    db = get_db()
    existing = db.users.find_one({"email": email})

    if existing and existing.get("passwordHash"):
        raise HTTPException(status_code=409, detail="An account already exists for that email.")

    now = datetime.now(timezone.utc)
    fields = {
        "name": (body.name or "").strip(),
        "phone": (body.phone or "").strip(),
        "email": email,
        "passwordHash": hash_password(body.password),
    }

    if existing:
        # An account carried over from the Firestore era: it has a profile
        # and past orders but no password yet (Firebase held those). Set the
        # password on the SAME document so the customer keeps their order
        # history instead of silently starting over under a new id.
        uid = existing["_id"]
        db.users.update_one({"_id": uid}, {"$set": fields})
    else:
        uid = uuid.uuid4().hex
        fields["createdAt"] = now
        db.users.insert_one({"_id": uid, **fields})

    return _issue(uid)


@router.post("/login", response_model=AuthTokenResponse)
def login(body: CustomerLoginRequest):
    email = (body.email or "").strip().lower()
    db = get_db()
    user = db.users.find_one({"email": email})
    # Same message whether the email is unknown or the password is wrong,
    # so this endpoint can't be used to discover which emails are registered.
    if not user or not verify_password(body.password or "", user.get("passwordHash", "")):
        raise HTTPException(status_code=401, detail="Incorrect email or password.")
    return _issue(user["_id"])


@router.post("/forgot-password")
def forgot_password(body: ForgotPasswordRequest):
    # Password reset used to go through Firebase's email service. With
    # Firebase Auth removed there is no mail sender configured, so rather
    # than pretend an email was sent, say so plainly.
    raise HTTPException(
        status_code=501,
        detail=(
            "Password reset by email isn't available yet. "
            "Please contact the shop and we'll reset it for you."
        ),
    )


@router.get("/me")
def get_my_profile(uid: str = Depends(get_current_customer_uid)):
    db = get_db()
    doc = db.users.find_one({"_id": uid})
    if doc is None:
        raise HTTPException(status_code=404, detail="Profile not found.")
    data = {k: v for k, v in doc.items() if k not in ("_id", "passwordHash")}
    data["uid"] = uid
    created = data.get("createdAt")
    if created is not None and hasattr(created, "isoformat"):
        data["createdAt"] = created.isoformat()
    return data


@router.get("/orders")
def get_my_orders(uid: str = Depends(get_current_customer_uid), limit: int = 50):
    db = get_db()
    docs = db.orders.find({"userId": uid}).sort("createdAt", -1).limit(limit)
    return [serialize(d) for d in docs]


@router.patch("/me")
def update_my_profile(body: ProfileUpdate, uid: str = Depends(get_current_customer_uid)):
    updates = {k: v.strip() if isinstance(v, str) else v
               for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="Nothing to update.")
    db = get_db()
    if db.users.update_one({"_id": uid}, {"$set": updates}).matched_count == 0:
        raise HTTPException(status_code=404, detail="Profile not found.")
    return get_my_profile(uid)


def _my_order_or_404(db, order_id: str, uid: str):
    """Fetch one order and refuse it unless it belongs to this customer.

    Without the userId check any signed-in customer could read anyone
    else's order by guessing an id -- names, phone numbers and addresses.
    """
    doc = db.orders.find_one({"_id": oid(order_id)})
    if doc is None or doc.get("userId") != uid:
        raise HTTPException(status_code=404, detail="Order not found.")
    return doc


@router.get("/orders/{order_id}")
def get_my_order(order_id: str, uid: str = Depends(get_current_customer_uid)):
    """One of the customer's own orders -- the app polls this to show
    live status while an order is being prepared."""
    return serialize(_my_order_or_404(get_db(), order_id, uid))


@router.patch("/orders/{order_id}/payment")
def set_my_order_payment(order_id: str, body: PaymentUpdate,
                         uid: str = Depends(get_current_customer_uid)):
    db = get_db()
    _my_order_or_404(db, order_id, uid)
    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="Nothing to update.")
    if "paymentMethod" in updates and updates["paymentMethod"] not in ("gpay", "cod"):
        raise HTTPException(status_code=400, detail="paymentMethod must be 'gpay' or 'cod'.")
    updates["updatedAt"] = datetime.now(timezone.utc)
    db.orders.update_one({"_id": oid(order_id)}, {"$set": updates})
    return serialize(db.orders.find_one({"_id": oid(order_id)}))
