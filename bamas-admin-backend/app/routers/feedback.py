from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from ..mongo_client import get_db
from ..mongo_utils import oid, serialize
from ..models import EnquiryCreate, EnquiryUpdate, ReviewCreate
from ..security import get_current_admin

# Everything customers submit through the bamas app that isn't an order:
# the Enquiry screen's contact form, and star-rating reviews.
#
# Since the move off Firestore, customers can no longer write these
# collections directly (no client-side Mongo SDK) -- the two PUBLIC
# POST endpoints below are new, replacing what used to be a direct
# Firestore write validated by security rules. The admin-only endpoints
# (list/mark-handled/delete) are unchanged in spirit.
router = APIRouter(tags=["feedback"], dependencies=[Depends(get_current_admin)])
public_router = APIRouter(tags=["feedback-public"])


@router.get("/enquiries")
def list_enquiries(limit: int = 200):
    db = get_db()
    docs = db.enquiries.find().sort("createdAt", -1).limit(limit)
    return [serialize(d) for d in docs]


@router.patch("/enquiries/{enquiry_id}")
def mark_enquiry_handled(enquiry_id: str, body: EnquiryUpdate):
    db = get_db()
    _id = oid(enquiry_id)
    if db.enquiries.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Enquiry not found.")
    db.enquiries.update_one({"_id": _id}, {"$set": {"handled": body.handled}})
    return serialize(db.enquiries.find_one({"_id": _id}))


@public_router.get("/reviews")
def list_reviews(limit: int = 200):
    db = get_db()
    docs = db.reviews.find().sort("createdAt", -1).limit(limit)
    return [serialize(d) for d in docs]


@router.delete("/reviews/{review_id}")
def delete_review(review_id: str):
    """Removes a review -- e.g. spam or abusive text."""
    db = get_db()
    _id = oid(review_id)
    if db.reviews.find_one({"_id": _id}) is None:
        raise HTTPException(status_code=404, detail="Review not found.")
    db.reviews.delete_one({"_id": _id})
    return {"deleted": True}


@public_router.post("/enquiries")
def submit_enquiry(body: EnquiryCreate):
    """PUBLIC -- the bamas customer app's Enquiry/contact form. No login
    needed, same as the old Firestore rule (`allow create if message
    under 2000 chars`)."""
    if len(body.message) > 2000:
        raise HTTPException(status_code=400, detail="Message must be under 2000 characters.")
    db = get_db()
    data = {
        "message": body.message.strip(),
        "customerName": (body.customerName or "").strip(),
        "customerPhone": (body.customerPhone or "").strip(),
        "handled": False,
        "createdAt": datetime.now(timezone.utc),
    }
    result = db.enquiries.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return serialize(data)


@public_router.post("/reviews")
def submit_review(body: ReviewCreate):
    """PUBLIC -- a star-rating review from the bamas customer app. No
    login needed, same validation the old Firestore rule enforced
    (rating 1-5, comment under 1000 chars)."""
    if not (1 <= body.rating <= 5):
        raise HTTPException(status_code=400, detail="rating must be between 1 and 5.")
    if len(body.comment) > 1000:
        raise HTTPException(status_code=400, detail="comment must be under 1000 characters.")
    db = get_db()
    data = {
        "rating": body.rating,
        "comment": body.comment.strip(),
        "customerName": (body.customerName or "").strip(),
        "createdAt": datetime.now(timezone.utc),
    }
    result = db.reviews.insert_one(dict(data))
    data["_id"] = result.inserted_id
    return serialize(data)
