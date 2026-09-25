"""
Staff logins.

Who may do what here:

  developer (super_admin)  create and edit ANY login -- other developers,
                           admins (owners), and branch managers. Sees every
                           account, including the ones an admin created.
  admin (owner)            create and edit BRANCH MANAGER logins only. Cannot
                           create another admin, cannot promote a manager
                           into one, and cannot touch a developer's account.
  branch manager           no access at all.

The admin is stopped from minting an owner-level account on purpose: that is
the one action that would let them grant themselves, or someone else, the
access the platform charges for.

Every account records `createdBy`, so the developer can see at a glance which
logins the admin made.

Deliberately absent: any endpoint that lists CUSTOMERS. A branch manager gets
a customer's name, phone and address on the order they are delivering and
nothing more -- no route in this backend hands back the customer base, so
there is nothing to export.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from ..models import AdminCreate, AdminUpdate
from ..mongo_client import get_db
from ..mongo_utils import oid, serialize
from ..security import (
    ALL_ROLES,
    ROLE_BRANCH_MANAGER,
    ROLE_OWNER,
    ROLE_SUPER_ADMIN,
    CurrentAdmin,
    get_current_admin,
    hash_password,
    require_global_admin,
)

# The router-level guard keeps branch managers out entirely. The finer
# developer-vs-admin split is enforced per route below.
router = APIRouter(prefix="/admins", tags=["admins"], dependencies=[Depends(require_global_admin)])

# What an admin (owner) is allowed to create and edit. One entry, on purpose.
OWNER_MANAGEABLE_ROLES = (ROLE_BRANCH_MANAGER,)


def _safe(doc) -> dict:
    """Never return the password hash, not even to the developer."""
    data = serialize(doc) or {}
    data.pop("passwordHash", None)
    return data


def _validate_role_and_branch(role: str, branch_id: str | None, db) -> None:
    if role not in ALL_ROLES:
        raise HTTPException(status_code=400, detail=f"role must be one of {sorted(ALL_ROLES)}")
    if role == ROLE_BRANCH_MANAGER:
        if not branch_id:
            raise HTTPException(status_code=400, detail="A branch manager must be assigned a branchId.")
        if db.branches.find_one({"_id": oid(branch_id)}) is None:
            raise HTTPException(status_code=400, detail="That branchId does not exist.")
    elif branch_id:
        raise HTTPException(
            status_code=400,
            detail="Only a branch_manager is tied to a branch; admins and developers see every branch.",
        )


def _assert_may_manage_role(admin: CurrentAdmin, role: str) -> None:
    """An admin may only ever deal in branch-manager accounts."""
    if admin.is_super_admin:
        return
    if role not in OWNER_MANAGEABLE_ROLES:
        raise HTTPException(
            status_code=403,
            detail="Only the developer can create or change an admin or developer login.",
        )


@router.get("")
def list_admins(admin: CurrentAdmin = Depends(get_current_admin)):
    """The developer sees every login. An admin sees the branch managers --
    which includes the ones the developer created, so both are looking at the
    same list of staff and neither is surprised by an account they cannot
    see."""
    db = get_db()
    filt = {} if admin.is_super_admin else {"role": ROLE_BRANCH_MANAGER}
    return [_safe(d) for d in db.admins.find(filt).sort("createdAt", 1)]


@router.post("")
def create_admin(body: AdminCreate, admin: CurrentAdmin = Depends(get_current_admin)):
    db = get_db()
    username = body.username.strip().lower()
    if not username or len(body.password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Username is required and the password must be at least 8 characters.",
        )
    if db.admins.find_one({"username": username}) is not None:
        raise HTTPException(status_code=409, detail="That username is already taken.")

    _assert_may_manage_role(admin, body.role)
    _validate_role_and_branch(body.role, body.branchId, db)

    now = datetime.now(timezone.utc)
    data = {
        "username": username,
        "name": body.name.strip() or username,
        "role": body.role,
        "branchId": body.branchId or None,
        "passwordHash": hash_password(body.password),
        "isActive": True,
        # Who made this login. The developer's staff list shows it, so an
        # account appearing overnight is traceable to whoever created it.
        "createdBy": admin.uid,
        "createdByName": admin.name or admin.username,
        "createdAt": now,
        "updatedAt": now,
    }
    result = db.admins.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return _safe(data)


@router.patch("/{admin_id}")
def update_admin(admin_id: str, body: AdminUpdate, admin: CurrentAdmin = Depends(get_current_admin)):
    """Change a name, move a manager to another branch, deactivate an
    account, or reset a forgotten password. There is no self-service password
    reset anywhere in this system, so this is how a locked-out manager gets
    back in."""
    db = get_db()
    _id = oid(admin_id)
    doc = db.admins.find_one({"_id": _id})
    if doc is None:
        raise HTTPException(status_code=404, detail="Admin not found.")

    current_role = doc.get("role", ROLE_BRANCH_MANAGER)
    # An admin may not touch a developer's or another admin's account at all,
    # not even to rename it -- checked against the account's CURRENT role
    # before anything in the request body is considered.
    _assert_may_manage_role(admin, current_role)

    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    password = updates.pop("password", None)

    new_role = updates.get("role", current_role)
    if "role" in updates:
        # ...and against the role they are trying to move it TO, which is
        # what stops an admin promoting a manager into a second admin.
        _assert_may_manage_role(admin, new_role)

    if "role" in updates or "branchId" in updates:
        if new_role == ROLE_BRANCH_MANAGER:
            branch_id = updates["branchId"] if "branchId" in updates else doc.get("branchId")
        else:
            # Promoting a manager to admin/developer drops the branch tie.
            # Cleared BEFORE validating, or the account's own stale branchId
            # trips the "admins are not tied to a branch" rule and the
            # promotion becomes impossible.
            branch_id = None
            updates["branchId"] = None
        _validate_role_and_branch(new_role, branch_id, db)

    # Locking yourself out is an easy mistake to make and an expensive one to
    # undo -- it would need a developer with server access.
    if updates.get("isActive") is False and str(doc.get("_id")) == admin.uid:
        raise HTTPException(status_code=400, detail="You cannot deactivate your own login.")

    if password:
        if len(password) < 8:
            raise HTTPException(status_code=400, detail="The password must be at least 8 characters.")
        updates["passwordHash"] = hash_password(password)

    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")

    updates["updatedAt"] = datetime.now(timezone.utc)
    db.admins.update_one({"_id": _id}, {"$set": updates})
    return _safe(db.admins.find_one({"_id": _id}))


@router.get("/roles/assignable")
def assignable_roles(admin: CurrentAdmin = Depends(get_current_admin)):
    """What the caller may put in the role dropdown. The app asks rather than
    hard-coding it, so the rule lives in one place -- here."""
    if admin.is_super_admin:
        return {"roles": [ROLE_SUPER_ADMIN, ROLE_OWNER, ROLE_BRANCH_MANAGER]}
    return {"roles": list(OWNER_MANAGEABLE_ROLES)}
