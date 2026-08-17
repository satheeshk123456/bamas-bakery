from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from ..firebase_client import get_db, get_messaging
from ..models import OrderStatusUpdate
from ..security import get_current_admin

router = APIRouter(prefix="/orders", tags=["orders"], dependencies=[Depends(get_current_admin)])

VALID_STATUSES = {"pending", "accepted", "rejected", "completed"}


def _serialize(doc) -> dict:
    data = doc.to_dict() or {}
    data["id"] = doc.id
    for key in ("createdAt", "updatedAt"):
        value = data.get(key)
        if value is not None and hasattr(value, "isoformat"):
            data[key] = value.isoformat()
    return data


@router.get("")
def list_orders(status: Optional[str] = None, limit: int = 50):
    """List orders, newest first. Optional ?status=pending|accepted|rejected|completed."""
    db = get_db()
    query = db.collection("orders")
    if status:
        if status not in VALID_STATUSES:
            raise HTTPException(status_code=400, detail=f"status must be one of {sorted(VALID_STATUSES)}")
        query = query.where("status", "==", status)
    query = query.order_by("createdAt", direction="DESCENDING").limit(limit)
    return [_serialize(doc) for doc in query.stream()]


@router.get("/{order_id}")
def get_order(order_id: str):
    db = get_db()
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Order not found.")
    return _serialize(doc)


@router.patch("/{order_id}/status")
def update_order_status(order_id: str, body: OrderStatusUpdate, admin: str = Depends(get_current_admin)):
    """
    Accept / reject / complete an order. Writing the new status into
    Firestore is enough — the existing `onOrderUpdated` Cloud Function
    (functions/index.js in the bamas project) automatically pushes a
    notification to the customer's phone the moment `status` changes, so
    nothing else needs to happen here.
    """
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"status must be one of {sorted(VALID_STATUSES)}")

    db = get_db()
    ref = db.collection("orders").document(order_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Order not found.")

    ref.update({"status": body.status, "updatedAt": datetime.now(timezone.utc)})
    return _serialize(ref.get())


@router.post("/{order_id}/notify-test")
def send_test_notification(order_id: str):
    """Manually re-send the 'new order' push for this order to the admin_orders
    topic — handy for testing that the admin app receives notifications
    correctly without having to place a real order."""
    db = get_db()
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Order not found.")
    order = doc.to_dict() or {}
    messaging = get_messaging()
    item_count = sum((i.get("quantity") or 0) for i in order.get("items", []))
    messaging.send(
        messaging.Message(
            topic="admin_orders",
            notification=messaging.Notification(
                title="New order received",
                body=f"{order.get('customerName', 'A customer')} • {item_count} item(s) • ₹{order.get('totalAmount', '')}",
            ),
            data={"type": "new_order", "orderId": order_id},
            android=messaging.AndroidConfig(priority="high"),
        )
    )
    return {"sent": True}
