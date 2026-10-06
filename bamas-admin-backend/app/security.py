from datetime import datetime, timedelta, timezone

import bcrypt
from bson import ObjectId
from bson.errors import InvalidId
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from .config import settings
from .mongo_client import get_db

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# Both shop admins and customers now authenticate with this backend's own
# JWTs (Firebase Authentication has been removed -- Firebase is kept ONLY
# for FCM push notifications). Because both token kinds are signed with the
# same secret, every token carries a "typ" claim and each dependency below
# accepts only its own kind. Without that, a customer's token would be
# accepted on admin endpoints.
TOKEN_TYPE_ADMIN = "admin"
TOKEN_TYPE_CUSTOMER = "customer"

# ---------------------------------------------------------------------------
# Roles (multi-branch)
# ---------------------------------------------------------------------------
# super_admin    -- the developer. The ONLY role that may create or delete a
#                   branch, because adding a branch changes licensing and the
#                   profit split. Also the only role that can create admins.
# owner          -- the shop owner. Sees every branch: all orders, all
#                   revenue, all menus. Cannot add branches.
# branch_manager -- runs one branch. Sees and touches ONLY its own branchId.
#                   Gets the customer's phone and address on an order (they
#                   have to ring the customer to deliver), but has no route
#                   that lists customers, so there is no way to export the
#                   customer base.
ROLE_SUPER_ADMIN = "super_admin"
ROLE_OWNER = "owner"
ROLE_BRANCH_MANAGER = "branch_manager"
ALL_ROLES = (ROLE_SUPER_ADMIN, ROLE_OWNER, ROLE_BRANCH_MANAGER)

# Roles whose view is the whole business rather than a single branch.
GLOBAL_ROLES = (ROLE_SUPER_ADMIN, ROLE_OWNER)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password:
        return False
    try:
        return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
    except (ValueError, TypeError):
        # Not a valid bcrypt hash (e.g. ADMIN_PASSWORD_HASH still a
        # placeholder) -- treat as "wrong password", don't 500.
        return False


def hash_password(plain_password: str) -> str:
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def create_access_token(subject: str, token_type: str = TOKEN_TYPE_ADMIN) -> str:
    minutes = (settings.customer_jwt_expires_minutes
               if token_type == TOKEN_TYPE_CUSTOMER
               else settings.jwt_expires_minutes)
    expire = datetime.now(timezone.utc) + timedelta(minutes=minutes)
    payload = {"sub": subject, "typ": token_type, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def _decode(token: str, expected_type: str) -> str:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired session, please log in again.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except JWTError:
        raise unauthorized
    subject = payload.get("sub")
    # A missing or mismatched "typ" is rejected: an admin token must never
    # satisfy a customer route, and a customer token must never satisfy an
    # admin route.
    if not subject or payload.get("typ") != expected_type:
        raise unauthorized
    return subject


def get_current_customer_uid(authorization: str | None = Header(None)) -> str:
    """Customer identity, from this backend's own JWT (issued by
    /account/register and /account/login)."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session, please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _decode(authorization.split(" ", 1)[1], TOKEN_TYPE_CUSTOMER)


# ---------------------------------------------------------------------------
# Admin identity
# ---------------------------------------------------------------------------
class CurrentAdmin:
    """Who is making this admin request, and what they are allowed to see.

    `branch_id` is None for super_admin and owner (they span every branch)
    and is the assigned branch's id string for a branch_manager.
    """

    def __init__(self, uid: str, username: str, name: str, role: str, branch_id: str | None):
        self.uid = uid
        self.username = username
        self.name = name
        self.role = role
        self.branch_id = branch_id

    # Kept so `str(admin)` still reads like the old return value (this
    # dependency used to hand back the username as a plain string).
    def __str__(self) -> str:
        return self.username

    @property
    def is_super_admin(self) -> bool:
        return self.role == ROLE_SUPER_ADMIN

    @property
    def sees_all_branches(self) -> bool:
        return self.role in GLOBAL_ROLES


def _admin_from_doc(doc: dict) -> CurrentAdmin:
    branch_id = doc.get("branchId")
    return CurrentAdmin(
        uid=str(doc.get("_id")),
        username=doc.get("username", ""),
        name=doc.get("name", ""),
        role=doc.get("role", ROLE_BRANCH_MANAGER),
        branch_id=str(branch_id) if branch_id else None,
    )


def get_current_admin(token: str = Depends(oauth2_scheme)) -> CurrentAdmin:
    """Shop admin identity, from /auth/login.

    Looks the account up in the `admins` collection on EVERY request rather
    than trusting the role baked into the token, so deactivating an admin or
    moving them to another branch takes effect at once instead of waiting up
    to 12 hours for their token to expire.

    Falls back to the single ADMIN_USERNAME/ADMIN_PASSWORD_HASH pair in .env
    and treats it as super_admin. That fallback is what keeps the already-
    published admin app working during and after this upgrade -- its live
    sessions carry a token whose `sub` is that username, and it must not be
    logged out mid-service.
    """
    subject = _decode(token, TOKEN_TYPE_ADMIN)
    db = get_db()

    doc = None
    try:
        doc = db.admins.find_one({"_id": ObjectId(subject)})
    except (InvalidId, TypeError):
        doc = None
    if doc is None:
        doc = db.admins.find_one({"username": subject})

    if doc is not None:
        if not doc.get("isActive", True):
            raise HTTPException(status_code=403, detail="This account has been deactivated.")
        return _admin_from_doc(doc)

    if settings.admin_username and subject == settings.admin_username:
        return CurrentAdmin(
            uid=subject,
            username=subject,
            name="Owner",
            role=ROLE_SUPER_ADMIN,
            branch_id=None,
        )

    raise HTTPException(status_code=403, detail="This account is no longer an admin.")


def require_roles(*roles: str):
    """Dependency factory: `Depends(require_roles(ROLE_SUPER_ADMIN))`."""

    def dependency(admin: CurrentAdmin = Depends(get_current_admin)) -> CurrentAdmin:
        if admin.role not in roles:
            raise HTTPException(
                status_code=403,
                detail="Your account does not have permission for this action.",
            )
        return admin

    return dependency


# Named dependencies for the two guards used most often.
require_super_admin = require_roles(ROLE_SUPER_ADMIN)
require_global_admin = require_roles(*GLOBAL_ROLES)


def branch_scope(admin: CurrentAdmin, requested_branch_id: str | None = None) -> dict:
    """The Mongo filter fragment that restricts a query to what this admin
    may see. Merge it into every admin query that touches branch-owned data.

    Enforcing the branch in the QUERY (and not by hiding buttons in the app)
    is the whole point: otherwise a branch manager reads another branch's
    order -- and its customer's name, phone and address -- just by guessing
    an id. Same failure this backend already had, and fixed, for customers
    reading each other's orders.
    """
    if admin.sees_all_branches:
        return {"branchId": requested_branch_id} if requested_branch_id else {}

    if not admin.branch_id:
        raise HTTPException(
            status_code=403,
            detail="No branch is assigned to this account. Ask the owner to assign one.",
        )
    if requested_branch_id and requested_branch_id != admin.branch_id:
        raise HTTPException(status_code=403, detail="This belongs to another branch.")
    return {"branchId": admin.branch_id}


def assert_can_touch_branch(admin: CurrentAdmin, branch_id: str | None) -> None:
    """Guard for a single document already fetched from the database."""
    if admin.sees_all_branches:
        return
    if not admin.branch_id or (branch_id or None) != admin.branch_id:
        # 404 rather than 403 on purpose -- a manager should not be able to
        # confirm that an order id exists in another branch.
        raise HTTPException(status_code=404, detail="Not found.")
