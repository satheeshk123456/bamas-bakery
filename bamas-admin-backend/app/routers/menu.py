from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..mongo_client import get_db
from ..mongo_utils import oid, serialize
from ..image_utils import ITEM_IMAGE_MAX_BYTES, presigned_url, upload_image
from ..models import CategoryCreate, CategoryUpdate, MenuItemCreate, MenuItemUpdate
from ..security import (
    CurrentAdmin,
    assert_can_touch_branch,
    get_current_admin,
    require_global_admin,
)

# Reads are PUBLIC (the bamas customer app's menu screen calls these
# directly, no login -- same as the old Firestore rule
# `allow read: if true`). Writes need an admin login, applied per-route
# below instead of at the router level.
router = APIRouter(prefix="/menu", tags=["menu"])


def _with_image(doc) -> dict:
    """Serializes a doc and turns its stored S3 key (if any) into a
    fresh, short-lived signed URL the app can load directly."""
    data = serialize(doc)
    if data is not None and data.get("imageUrl"):
        data["imageUrl"] = presigned_url(data["imageUrl"])
    return data


# Categories are deliberately NOT per-branch: they are the brand's menu
# structure ("Burgers", "Drinks"), the same everywhere, and duplicating them
# per branch would double the owner's data entry for no gain. Only the
# ITEMS inside them carry a branchId. Creating/editing a category is
# therefore owner-level, not something a single branch manager can do.
@router.get("/categories")
def list_categories(includeInactive: bool = False):
    """The customer app gets only the LIVE categories; the admin app passes
    ?includeInactive=true so the owner can still see, and switch back on,
    a category they have hidden.

    Categories created before this flag existed have no isActive field at
    all, and `$ne: False` counts those as live -- so nothing disappears
    from the menu the moment this deploys."""
    db = get_db()
    filt = {} if includeInactive else {"isActive": {"$ne": False}}
    docs = db.categories.find(filt).sort("sortOrder", 1)
    return [_with_image(d) for d in docs]


@router.patch("/categories/{category_id}", dependencies=[Depends(require_global_admin)])
def update_category(category_id: str, body: CategoryUpdate):
    """Rename, reorder, or hide a category.

    Hiding (isActive=false) is the safe alternative to deleting: the
    category disappears from the customer app at once, but its items and
    every past order that references it are untouched, and it can be
    switched back on."""
    db = get_db()
    _id = oid(category_id)
    if db.categories.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Category not found.")

    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    db.categories.update_one({"_id": _id}, {"$set": updates})
    return _with_image(db.categories.find_one({"_id": _id}))


@router.delete("/categories/{category_id}", dependencies=[Depends(require_global_admin)])
def delete_category(category_id: str):
    """Permanently remove a category -- but only while nothing uses it.

    Deleting one that still has items would leave those items pointing at
    an id that no longer exists: gone from every category filter, yet still
    orderable from search. That is the kind of half-broken state nobody
    notices until a customer does, so the items have to be moved or removed
    first and the error says so."""
    db = get_db()
    _id = oid(category_id)
    if db.categories.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Category not found.")

    in_use = db.menuItems.count_documents({"categoryId": category_id})
    if in_use:
        raise HTTPException(
            status_code=409,
            detail=(
                f"{in_use} menu item(s) are still in this category. Move them to "
                "another category first, or switch this one off instead of deleting it."
            ),
        )

    db.categories.delete_one({"_id": _id})
    return {"deleted": True, "id": category_id}


@router.post("/categories", dependencies=[Depends(require_global_admin)])
def create_category(body: CategoryCreate):
    """Adds a brand-new menu category (e.g. "Beverages", "Desserts")."""
    db = get_db()
    existing_count = db.categories.count_documents({})
    data = {
        "name": body.name.strip(),
        "imageUrl": body.imageUrl or "",
        "sortOrder": body.sortOrder if body.sortOrder is not None else existing_count + 1,
        "isActive": True,
    }
    result = db.categories.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return _with_image(data)


@router.post("/categories/{category_id}/image", dependencies=[Depends(require_global_admin)])
async def upload_category_image(category_id: str, file: UploadFile = File(...)):
    db = get_db()
    _id = oid(category_id)
    if db.categories.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Category not found.")
    key = await upload_image(file, prefix="categories", doc_id=category_id, max_bytes=ITEM_IMAGE_MAX_BYTES)
    db.categories.update_one({"_id": _id}, {"$set": {"imageUrl": key}})
    return {"imageUrl": presigned_url(key)}


@router.get("/items")
def list_items(categoryId: str | None = None, branchId: str | None = None):
    """The customer app's menu.

    ?branchId= restricts the list to one branch's items. It is OPTIONAL on
    purpose: the customer app already in people's hands does not send it,
    and omitting it returns everything exactly as before. Once the
    branch-aware build ships, every call carries a branchId.

    Items created before the multi-branch upgrade have no branchId at all.
    deploy/migrate_branches.py backfills them onto the default branch --
    run it, or those items will vanish from the app the moment the new
    build starts filtering.
    """
    db = get_db()
    filt: dict = {}
    if categoryId:
        filt["categoryId"] = categoryId
    if branchId:
        filt["branchId"] = branchId
    return [_with_image(d) for d in db.menuItems.find(filt)]


@router.post("/items")
def create_item(body: MenuItemCreate, admin: CurrentAdmin = Depends(get_current_admin)):
    """Adds a brand-new item -- the admin app's "+" (add) icon. Writes
    into the same `menuItems` collection the customer app's GET
    /menu/items reads, so the item shows up immediately.

    A branch manager may only add items to their own branch: their branchId
    is forced in below regardless of what the request body claims."""
    db = get_db()
    data = body.model_dump()

    if admin.sees_all_branches:
        if not data.get("branchId"):
            raise HTTPException(status_code=400, detail="branchId is required -- which branch sells this item?")
        if db.branches.find_one({"_id": oid(data["branchId"])}) is None:
            raise HTTPException(status_code=400, detail="That branchId does not exist.")
    else:
        # Ignore whatever the client sent; a manager's items are their own.
        data["branchId"] = admin.branch_id
        assert_can_touch_branch(admin, data["branchId"])

    data["sortOrder"] = db.menuItems.count_documents({"branchId": data["branchId"]}) + 1
    result = db.menuItems.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return _with_image(data)


@router.patch("/items/{item_id}")
def update_item(item_id: str, body: MenuItemUpdate, admin: CurrentAdmin = Depends(get_current_admin)):
    """Toggle availability ('sold out'), change price, name, or
    description -- shows up in the customer app immediately.

    This is the route a branch manager uses most (marking things sold out),
    so the branch check matters: without it one branch could mark another
    branch's items unavailable."""
    db = get_db()
    _id = oid(item_id)
    doc = db.menuItems.find_one({"_id": _id})
    if doc is None:
        raise HTTPException(status_code=404, detail="Menu item not found.")
    assert_can_touch_branch(admin, doc.get("branchId"))

    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if "branchId" in updates and not admin.sees_all_branches:
        raise HTTPException(status_code=403, detail="Only the owner can move an item to another branch.")
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    db.menuItems.update_one({"_id": _id}, {"$set": updates})
    return _with_image(db.menuItems.find_one({"_id": _id}))


@router.post("/items/{item_id}/image")
async def upload_item_image(
    item_id: str,
    file: UploadFile = File(...),
    admin: CurrentAdmin = Depends(get_current_admin),
):
    db = get_db()
    _id = oid(item_id)
    doc = db.menuItems.find_one({"_id": _id})
    if doc is None:
        raise HTTPException(status_code=404, detail="Menu item not found.")
    assert_can_touch_branch(admin, doc.get("branchId"))
    key = await upload_image(file, prefix="menu-items", doc_id=item_id, max_bytes=ITEM_IMAGE_MAX_BYTES)
    db.menuItems.update_one({"_id": _id}, {"$set": {"imageUrl": key}})
    return {"imageUrl": presigned_url(key)}
