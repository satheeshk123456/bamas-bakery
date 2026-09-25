"""
Admin login.

Before multi-branch there was exactly one admin: a username and a bcrypt
hash in .env. That still works, and is checked LAST here, because the admin
app already published to the Play Store logs in with it -- breaking that on
deploy would stop the shop taking orders. It is treated as super_admin.

Real admin accounts now live in the `admins` collection, each with a role
and (for a branch manager) the branchId they are confined to. The token's
`sub` is the account's Mongo id; app/security.py re-reads the account on
every request so a role change or a deactivation applies immediately.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status

from ..config import settings
from ..models import AdminLoginResponse, LoginRequest
from ..mongo_client import get_db
from ..security import (
    ROLE_SUPER_ADMIN,
    TOKEN_TYPE_ADMIN,
    create_access_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=AdminLoginResponse)
def login(body: LoginRequest):
    username = (body.username or "").strip()
    db = get_db()

    # Usernames are stored lower-cased; compare case-insensitively so an
    # owner typing "Ramesh" still gets in.
    doc = db.admins.find_one({"username": username.lower()})
    if doc is not None:
        if not doc.get("isActive", True):
            raise HTTPException(status_code=403, detail="This account has been deactivated.")
        if not verify_password(body.password, doc.get("passwordHash", "")):
            # Same message for "no such user" and "wrong password" -- never
            # reveal which one was wrong.
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password.",
            )
        db.admins.update_one({"_id": doc["_id"]}, {"$set": {"lastLoginAt": datetime.now(timezone.utc)}})
        branch_id = doc.get("branchId")
        return AdminLoginResponse(
            access_token=create_access_token(subject=str(doc["_id"]), token_type=TOKEN_TYPE_ADMIN),
            role=doc.get("role", ""),
            name=doc.get("name", ""),
            branchId=str(branch_id) if branch_id else None,
        )

    # Bootstrap account from .env -- the original single admin.
    if (
        settings.admin_username
        and username == settings.admin_username
        and verify_password(body.password, settings.admin_password_hash)
    ):
        return AdminLoginResponse(
            access_token=create_access_token(subject=username, token_type=TOKEN_TYPE_ADMIN),
            role=ROLE_SUPER_ADMIN,
            name="Owner",
            branchId=None,
        )

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect username or password.",
    )
