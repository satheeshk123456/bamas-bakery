from fastapi import APIRouter, Depends, HTTPException

from ..firebase_client import get_db
from ..models import ShopSettingsUpdate
from ..security import get_current_admin

router = APIRouter(prefix="/shop-settings", tags=["shop"], dependencies=[Depends(get_current_admin)])


@router.get("")
def get_settings():
    db = get_db()
    doc = db.collection("shopSettings").document("main").get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="shopSettings/main not found.")
    return doc.to_dict()


@router.patch("")
def update_settings(body: ShopSettingsUpdate):
    """E.g. flip the shop open/closed toggle from the admin app."""
    db = get_db()
    ref = db.collection("shopSettings").document("main")
    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    ref.update(updates)
    return ref.get().to_dict()
