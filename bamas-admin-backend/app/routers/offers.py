from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..mongo_client import get_db
from ..mongo_utils import oid, serialize
from ..image_utils import ITEM_IMAGE_MAX_BYTES, presigned_url, upload_image
from ..models import OfferCreate, OfferUpdate
from ..security import get_current_admin

# Home-page promo banners the admin can add/remove any time.
#
# Since the move off Firestore, the bamas customer app can no longer read
# this collection directly (no client-side Mongo SDK) -- it now calls the
# PUBLIC GET /offers/active below instead. Everything else here
# (list-all/create/edit/delete/image) stays admin-only, same as before.
router = APIRouter(prefix="/offers", tags=["offers"])


def _with_image(doc) -> dict:
    data = serialize(doc)
    if data is not None and data.get("imageUrl"):
        data["imageUrl"] = presigned_url(data["imageUrl"])
    return data


@router.get("/active")
def list_active_offers():
    """PUBLIC. Only isActive offers, sorted for the carousel -- what the
    bamas customer app's home screen calls."""
    db = get_db()
    docs = db.offers.find({"isActive": True}).sort("sortOrder", 1)
    return [_with_image(d) for d in docs]


@router.get("", dependencies=[Depends(get_current_admin)])
def list_offers():
    """All offers, including inactive ones -- the admin app's management
    screen, so a paused offer can still be found and re-enabled."""
    db = get_db()
    docs = db.offers.find().sort("sortOrder", 1)
    return [_with_image(d) for d in docs]


@router.post("", dependencies=[Depends(get_current_admin)])
def create_offer(body: OfferCreate):
    db = get_db()
    existing_count = db.offers.count_documents({})
    data = {
        "title": body.title.strip(),
        "subtitle": (body.subtitle or "").strip(),
        "imageUrl": "",
        "isActive": body.isActive,
        "sortOrder": existing_count + 1,
    }
    result = db.offers.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return _with_image(data)


@router.patch("/{offer_id}", dependencies=[Depends(get_current_admin)])
def update_offer(offer_id: str, body: OfferUpdate):
    db = get_db()
    _id = oid(offer_id)
    if db.offers.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Offer not found.")
    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update.")
    db.offers.update_one({"_id": _id}, {"$set": updates})
    return _with_image(db.offers.find_one({"_id": _id}))


@router.post("/{offer_id}/image", dependencies=[Depends(get_current_admin)])
async def upload_offer_image(offer_id: str, file: UploadFile = File(...)):
    db = get_db()
    _id = oid(offer_id)
    if db.offers.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Offer not found.")
    key = await upload_image(file, prefix="offers", doc_id=offer_id, max_bytes=ITEM_IMAGE_MAX_BYTES)
    db.offers.update_one({"_id": _id}, {"$set": {"imageUrl": key}})
    return {"imageUrl": presigned_url(key)}


@router.delete("/{offer_id}", dependencies=[Depends(get_current_admin)])
def delete_offer(offer_id: str):
    db = get_db()
    _id = oid(offer_id)
    if db.offers.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Offer not found.")
    db.offers.delete_one({"_id": _id})
    return {"deleted": True}
