from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from ..mongo_client import get_db
from ..image_utils import SHOP_IMAGE_MAX_BYTES, presigned_url, upload_image
from ..models import ShopSettingsUpdate
from ..security import get_current_admin

# GET is PUBLIC (same as the old Firestore rule `allow read: if true`) --
# the bamas customer app reads this for the shop name/hours/WhatsApp
# number/UPI id/banners on nearly every screen. Writes are admin-only.
router = APIRouter(prefix="/shop-settings", tags=["shop"])

_IMAGE_FIELDS = {"logoUrl", "heroImageUrl", "gpayQrUrl", "weekendOfferImageUrl"}


def _with_images(data: dict) -> dict:
    data = dict(data)
    for field in _IMAGE_FIELDS:
        if data.get(field):
            data[field] = presigned_url(data[field])
    return data


@router.get("")
def get_settings():
    db = get_db()
    doc = db.shopSettings.find_one({"_id": "main"})
    if doc is None:
        raise HTTPException(status_code=404, detail="shopSettings/main not found.")
    doc = dict(doc)
    doc.pop("_id", None)
    return _with_images(doc)


@router.patch("", dependencies=[Depends(get_current_admin)])
def update_settings(body: ShopSettingsUpdate):
    """E.g. flip the shop open/closed toggle from the admin app."""
    db = get_db()
    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    db.shopSettings.update_one({"_id": "main"}, {"$set": updates}, upsert=True)
    doc = dict(db.shopSettings.find_one({"_id": "main"}))
    doc.pop("_id", None)
    return _with_images(doc)


@router.post("/image", dependencies=[Depends(get_current_admin)])
async def upload_shop_image(field: str = Form(...), file: UploadFile = File(...)):
    """Uploads a photo for one of the shop's own images (logo, hero
    banner, GPay QR, weekend-offer banner). `field` says which one."""
    if field not in _IMAGE_FIELDS:
        raise HTTPException(status_code=400, detail=f"field must be one of {sorted(_IMAGE_FIELDS)}")
    key = await upload_image(file, prefix="shop", doc_id=field, max_bytes=SHOP_IMAGE_MAX_BYTES)
    db = get_db()
    db.shopSettings.update_one({"_id": "main"}, {"$set": {field: key}}, upsert=True)
    return {field: presigned_url(key)}
