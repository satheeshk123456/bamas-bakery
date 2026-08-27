from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from ..firebase_client import get_db
from ..image_utils import SHOP_IMAGE_MAX_BYTES, file_to_data_uri
from ..models import ShopSettingsUpdate
from ..security import get_current_admin

router = APIRouter(prefix="/shop-settings", tags=["shop"], dependencies=[Depends(get_current_admin)])

# The only shopSettings fields that are photos -- everything else in
# ShopSettingsUpdate is plain text/boolean and goes through the regular
# PATCH below instead.
_IMAGE_FIELDS = {"logoUrl", "heroImageUrl", "gpayQrUrl", "weekendOfferImageUrl"}


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


@router.post("/image")
async def upload_shop_image(field: str = Form(...), file: UploadFile = File(...)):
    """Uploads a photo for one of the shop's own images (logo, hero
    banner, GPay QR, weekend-offer banner) -- e.g. from the admin app's
    Settings screen. `field` says which one. Kept separate from the
    plain-text PATCH above because this one takes a file, not JSON.
    Stored as base64 straight in shopSettings/main (see app/image_utils.py
    for why, instead of Firebase Storage) -- capped smaller than a menu
    item's photo since up to four of these can live in that ONE document
    at once and Firestore caps a document at 1 MiB total."""
    if field not in _IMAGE_FIELDS:
        raise HTTPException(status_code=400, detail=f"field must be one of {sorted(_IMAGE_FIELDS)}")
    data_uri = await file_to_data_uri(file, max_bytes=SHOP_IMAGE_MAX_BYTES)
    db = get_db()
    db.collection("shopSettings").document("main").set({field: data_uri}, merge=True)
    return {field: data_uri}
