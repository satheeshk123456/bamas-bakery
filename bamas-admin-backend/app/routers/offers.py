from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..firebase_client import get_db
from ..image_utils import ITEM_IMAGE_MAX_BYTES, file_to_data_uri
from ..models import OfferCreate, OfferUpdate
from ..security import get_current_admin

# Home-page promo banners the admin can add/remove any time, no app
# update needed. Admin-only end to end (list/create/edit/delete/image) --
# the customer app never calls this backend for offers at all, it reads
# the SAME `offers` Firestore collection directly via the client SDK
# (public read, see firestore.rules), exactly like it already does for
# categories and menuItems, and filters to isActive itself. That keeps
# the carousel live-updating without any extra network round trip.
router = APIRouter(prefix="/offers", tags=["offers"], dependencies=[Depends(get_current_admin)])


def _serialize(doc) -> dict:
    data = doc.to_dict() or {}
    data["id"] = doc.id
    return data


@router.get("")
def list_offers():
    """All offers, including inactive ones -- this is for the admin app's
    management screen so a paused offer can still be found and re-enabled."""
    db = get_db()
    docs = db.collection("offers").order_by("sortOrder").stream()
    return [_serialize(d) for d in docs]


@router.post("")
def create_offer(body: OfferCreate):
    db = get_db()
    existing_count = len(list(db.collection("offers").stream()))
    data = {
        "title": body.title.strip(),
        "subtitle": (body.subtitle or "").strip(),
        "imageUrl": "",
        "isActive": body.isActive,
        "sortOrder": existing_count + 1,
    }
    ref = db.collection("offers").document()
    ref.set(data)
    return _serialize(ref.get())


@router.patch("/{offer_id}")
def update_offer(offer_id: str, body: OfferUpdate):
    db = get_db()
    ref = db.collection("offers").document(offer_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Offer not found.")
    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    ref.update(updates)
    return _serialize(ref.get())


@router.post("/{offer_id}/image")
async def upload_offer_image(offer_id: str, file: UploadFile = File(...)):
    db = get_db()
    ref = db.collection("offers").document(offer_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Offer not found.")
    data_uri = await file_to_data_uri(file, max_bytes=ITEM_IMAGE_MAX_BYTES)
    ref.update({"imageUrl": data_uri})
    return {"imageUrl": data_uri}


@router.delete("/{offer_id}")
def delete_offer(offer_id: str):
    db = get_db()
    ref = db.collection("offers").document(offer_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Offer not found.")
    ref.delete()
    return {"deleted": True}
