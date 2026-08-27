from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..firebase_client import get_db
from ..image_utils import ITEM_IMAGE_MAX_BYTES, file_to_data_uri
from ..models import CategoryCreate, MenuItemCreate, MenuItemUpdate
from ..security import get_current_admin

router = APIRouter(prefix="/menu", tags=["menu"], dependencies=[Depends(get_current_admin)])


def _serialize(doc) -> dict:
    data = doc.to_dict() or {}
    data["id"] = doc.id
    return data


@router.get("/categories")
def list_categories():
    db = get_db()
    docs = db.collection("categories").order_by("sortOrder").stream()
    return [_serialize(d) for d in docs]


@router.post("/categories")
def create_category(body: CategoryCreate):
    """Adds a brand-new menu category (e.g. "Beverages", "Desserts") --
    this is what the admin app was missing: it could add items to an
    existing category, but never create a whole new one to put them in."""
    db = get_db()
    existing_count = len(list(db.collection("categories").stream()))
    data = {
        "name": body.name.strip(),
        "imageUrl": body.imageUrl or "",
        "sortOrder": body.sortOrder if body.sortOrder is not None else existing_count + 1,
    }
    ref = db.collection("categories").document()
    ref.set(data)
    return _serialize(ref.get())


@router.post("/categories/{category_id}/image")
async def upload_category_image(category_id: str, file: UploadFile = File(...)):
    db = get_db()
    ref = db.collection("categories").document(category_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Category not found.")
    data_uri = await file_to_data_uri(file, max_bytes=ITEM_IMAGE_MAX_BYTES)
    ref.update({"imageUrl": data_uri})
    return {"imageUrl": data_uri}


@router.get("/items")
def list_items(categoryId: str | None = None):
    db = get_db()
    query = db.collection("menuItems")
    if categoryId:
        query = query.where("categoryId", "==", categoryId)
    return [_serialize(d) for d in query.stream()]


@router.post("/items")
def create_item(body: MenuItemCreate):
    """Adds a brand-new item — this is what the admin app's new "+" (add)
    icon on the Menu screen calls. Writes into the same `menuItems`
    collection the customer app reads live, so the item shows up on the
    `bamas` app's Menu tab immediately, no reinstall or redeploy needed."""
    db = get_db()
    existing_count = len(list(db.collection("menuItems").stream()))
    data = body.model_dump()
    data["sortOrder"] = existing_count + 1
    ref = db.collection("menuItems").document()
    ref.set(data)
    return _serialize(ref.get())


@router.patch("/items/{item_id}")
def update_item(item_id: str, body: MenuItemUpdate):
    """Toggle availability ('sold out'), change price, name, or description.
    This writes straight into the same `menuItems` collection the customer
    app reads live — changes show up in the customer app immediately, no
    reinstall or redeploy needed (same behavior as the existing admin
    website)."""
    db = get_db()
    ref = db.collection("menuItems").document(item_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Menu item not found.")

    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    ref.update(updates)
    return _serialize(ref.get())


@router.post("/items/{item_id}/image")
async def upload_item_image(item_id: str, file: UploadFile = File(...)):
    """The endpoint the admin app's menu editor (menu_service.dart's
    uploadImage) has been calling all along -- it just never existed on
    the backend, so "add item with photo" silently failed. Stores the
    photo as a base64 data: URI straight in the item's own Firestore
    document (see app/image_utils.py for why, instead of Firebase
    Storage)."""
    db = get_db()
    ref = db.collection("menuItems").document(item_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Menu item not found.")
    data_uri = await file_to_data_uri(file, max_bytes=ITEM_IMAGE_MAX_BYTES)
    ref.update({"imageUrl": data_uri})
    return {"imageUrl": data_uri}
