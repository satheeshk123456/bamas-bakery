from fastapi import APIRouter, Depends, HTTPException

from ..firebase_client import get_db
from ..models import MenuItemUpdate
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


@router.get("/items")
def list_items(categoryId: str | None = None):
    db = get_db()
    query = db.collection("menuItems")
    if categoryId:
        query = query.where("categoryId", "==", categoryId)
    return [_serialize(d) for d in query.stream()]


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
