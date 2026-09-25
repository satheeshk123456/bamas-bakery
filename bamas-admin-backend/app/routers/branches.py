"""
Branches -- the multi-branch layer added on top of the original single-shop
backend.

What lives on a BRANCH (operational, differs per location):
    name, address, contactPhone (the WhatsApp number orders are sent to),
    upiId + gpayQrUrl (each branch banks its own money), isOpen.

What stays in shopSettings (brand-wide, one for the whole business):
    shopName, logoUrl, heroImageUrl, heroHeadline, heroTagline, the weekend
    offer banner, and the home-page offer carousel.

Creating a branch is restricted to super_admin because adding a location
changes licensing and the profit split -- an owner must not be able to add
one unilaterally. Everything else about a branch (open/closed, phone, UPI)
is editable by the owner, and by that branch's own manager.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..image_utils import SHOP_IMAGE_MAX_BYTES, presigned_url, upload_image
from ..models import BranchCreate, BranchUpdate
from ..mongo_client import get_db
from ..mongo_utils import oid, serialize
from ..security import (
    CurrentAdmin,
    assert_can_touch_branch,
    get_current_admin,
    require_super_admin,
)

# GET is PUBLIC: the customer app has to show the branch picker before
# anyone has logged in. Writes are admin-only, per-route below.
router = APIRouter(prefix="/branches", tags=["branches"])

_IMAGE_FIELDS = {"gpayQrUrl", "imageUrl"}


def _public(doc) -> dict:
    data = serialize(doc)
    if data is None:
        return {}
    for field in _IMAGE_FIELDS:
        if data.get(field):
            data[field] = presigned_url(data[field])
    return data


@router.get("")
def list_branches(includeInactive: bool = False):
    """Every branch the customer app can order from, for the branch picker.

    Public and unauthenticated on purpose -- the picker is the first screen,
    before login. Only non-secret operational fields are stored here, so
    there is nothing to leak.
    """
    db = get_db()
    filt = {} if includeInactive else {"isActive": {"$ne": False}}
    docs = db.branches.find(filt).sort("sortOrder", 1)
    return [_public(d) for d in docs]


@router.get("/{branch_id}")
def get_branch(branch_id: str):
    db = get_db()
    doc = db.branches.find_one({"_id": oid(branch_id)})
    if doc is None:
        raise HTTPException(status_code=404, detail="Branch not found.")
    return _public(doc)


@router.post("", dependencies=[Depends(require_super_admin)])
def create_branch(body: BranchCreate):
    """SUPER ADMIN ONLY.

    Adding a branch has commercial consequences (licensing, profit share),
    so this is deliberately not something the shop owner can do from the
    admin app -- the guard is the dependency above, enforced server-side.
    """
    db = get_db()
    now = datetime.now(timezone.utc)
    data = {
        "name": body.name.strip(),
        "address": (body.address or "").strip(),
        "contactPhone": (body.contactPhone or "").strip(),
        "upiId": (body.upiId or "").strip(),
        "gpayQrUrl": "",
        "imageUrl": "",
        "isOpen": body.isOpen,
        "isActive": True,
        "sortOrder": body.sortOrder if body.sortOrder is not None else db.branches.count_documents({}) + 1,
        "createdAt": now,
        "updatedAt": now,
    }
    result = db.branches.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return _public(data)


@router.patch("/{branch_id}")
def update_branch(branch_id: str, body: BranchUpdate, admin: CurrentAdmin = Depends(get_current_admin)):
    """Open/closed, phone, address, UPI id.

    An owner may edit any branch; a branch manager only their own. Note a
    manager CAN flip their own branch open/closed and change its UPI id --
    that is their shop's day-to-day running, not a global setting.
    """
    db = get_db()
    _id = oid(branch_id)
    doc = db.branches.find_one({"_id": _id})
    if doc is None:
        raise HTTPException(status_code=404, detail="Branch not found.")
    assert_can_touch_branch(admin, branch_id)

    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    # Deactivating a branch hides it from the customer app entirely, which is
    # close enough to deleting it to deserve the same restriction.
    if "isActive" in updates and not admin.is_super_admin:
        raise HTTPException(status_code=403, detail="Only the super admin can activate or deactivate a branch.")
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")

    updates["updatedAt"] = datetime.now(timezone.utc)
    db.branches.update_one({"_id": _id}, {"$set": updates})
    return _public(db.branches.find_one({"_id": _id}))


@router.post("/{branch_id}/image")
async def upload_branch_image(
    branch_id: str,
    field: str = "gpayQrUrl",
    file: UploadFile = File(...),
    admin: CurrentAdmin = Depends(get_current_admin),
):
    """The branch's own payment QR (or a photo of the shopfront)."""
    if field not in _IMAGE_FIELDS:
        raise HTTPException(status_code=400, detail=f"field must be one of {sorted(_IMAGE_FIELDS)}")
    db = get_db()
    _id = oid(branch_id)
    if db.branches.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Branch not found.")
    assert_can_touch_branch(admin, branch_id)

    key = await upload_image(file, prefix="branches", doc_id=branch_id, max_bytes=SHOP_IMAGE_MAX_BYTES)
    db.branches.update_one({"_id": _id}, {"$set": {field: key, "updatedAt": datetime.now(timezone.utc)}})
    return {field: presigned_url(key)}


@router.get("/{branch_id}/summary", dependencies=[Depends(get_current_admin)])
def branch_summary(branch_id: str, admin: CurrentAdmin = Depends(get_current_admin)):
    """Order counts for one branch -- what the manager's dashboard shows.

    Revenue totals across ALL branches are deliberately not here; that is the
    owner's consolidated view, served by the existing /orders endpoints.
    """
    assert_can_touch_branch(admin, branch_id)
    db = get_db()
    counts = {}
    for status_name in ("pending", "accepted", "completed", "rejected"):
        counts[status_name] = db.orders.count_documents({"branchId": branch_id, "status": status_name})
    return {"branchId": branch_id, "orderCounts": counts}
