from fastapi import APIRouter, Depends, HTTPException

from ..firebase_client import get_db
from ..models import EnquiryUpdate
from ..security import get_current_admin

# Everything customers submit through the bamas app that isn't an order:
# the Enquiry screen's contact form, and star-rating reviews. Both were
# already being written straight to Firestore (see bamas's
# firestore_service.dart submitEnquiry/addReview) but the admin app had
# no way to ever read them back -- this closes that gap.
router = APIRouter(tags=["feedback"], dependencies=[Depends(get_current_admin)])


def _serialize(doc) -> dict:
    data = doc.to_dict() or {}
    data["id"] = doc.id
    created = data.get("createdAt")
    if created is not None and hasattr(created, "isoformat"):
        data["createdAt"] = created.isoformat()
    return data


@router.get("/enquiries")
def list_enquiries(limit: int = 200):
    db = get_db()
    docs = (
        db.collection("enquiries")
        .order_by("createdAt", direction="DESCENDING")
        .limit(limit)
        .stream()
    )
    return [_serialize(d) for d in docs]


@router.patch("/enquiries/{enquiry_id}")
def mark_enquiry_handled(enquiry_id: str, body: EnquiryUpdate):
    db = get_db()
    ref = db.collection("enquiries").document(enquiry_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Enquiry not found.")
    ref.update({"handled": body.handled})
    return _serialize(ref.get())


@router.get("/reviews")
def list_reviews(limit: int = 200):
    db = get_db()
    docs = (
        db.collection("reviews")
        .order_by("createdAt", direction="DESCENDING")
        .limit(limit)
        .stream()
    )
    return [_serialize(d) for d in docs]


@router.delete("/reviews/{review_id}")
def delete_review(review_id: str):
    """Removes a review -- e.g. spam or abusive text. Firestore rules
    already only allow an admin to delete reviews; this is the admin
    app's way to trigger that (it never talks to Firestore directly)."""
    db = get_db()
    ref = db.collection("reviews").document(review_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Review not found.")
    ref.delete()
    return {"deleted": True}
