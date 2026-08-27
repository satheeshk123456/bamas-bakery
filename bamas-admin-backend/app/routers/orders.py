import csv
import io as _io
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from firebase_admin import firestore

from ..firebase_client import get_db, get_messaging
from ..models import OrderCreate, OrderStatusUpdate
from ..security import get_current_admin

# The shop's own local day, used to interpret ?from_date/?to_date on the
# date-filter and CSV-export endpoints below. Fixed offset is exact for
# India (no DST), so this needs no extra timezone-data dependency.
IST = timezone(timedelta(hours=5, minutes=30))

router = APIRouter(prefix="/orders", tags=["orders"], dependencies=[Depends(get_current_admin)])

# Separate, unauthenticated router for the one endpoint the customer app
# calls directly (placing an order) — every other order route needs an
# admin login, this one doesn't.
public_router = APIRouter(prefix="/orders", tags=["orders-public"])

VALID_STATUSES = {"pending", "accepted", "rejected", "completed"}

# Same wording the old onOrderUpdated Cloud Function used, kept here so the
# customer sees the same messages now that this backend sends them instead.
STATUS_NOTIFICATIONS = {
    "accepted": ("Order confirmed!", "Your order has been accepted. Open the app to pay online."),
    "rejected": ("Order could not be confirmed", "Sorry, we could not confirm your order. Please call the shop."),
    "completed": ("Order completed", "Thanks for ordering with us!"),
}


def _serialize(doc) -> dict:
    data = doc.to_dict() or {}
    data["id"] = doc.id
    for key in ("createdAt", "updatedAt"):
        value = data.get(key)
        if value is not None and hasattr(value, "isoformat"):
            data[key] = value.isoformat()
    return data


def _parse_date_range(from_date: Optional[str], to_date: Optional[str]):
    """Turns ?from_date=YYYY-MM-DD / ?to_date=YYYY-MM-DD into timezone-aware
    UTC-comparable datetimes covering that whole IST calendar day
    (inclusive on both ends) -- e.g. from_date=to_date=2026-08-01 covers
    all of August 1st in the shop's own local time, not UTC."""
    start = end = None
    if from_date:
        try:
            start = datetime.strptime(from_date, "%Y-%m-%d").replace(tzinfo=IST)
        except ValueError:
            raise HTTPException(status_code=400, detail="from_date must be in YYYY-MM-DD format.")
    if to_date:
        try:
            end = datetime.strptime(to_date, "%Y-%m-%d").replace(
                hour=23, minute=59, second=59, microsecond=999999, tzinfo=IST
            )
        except ValueError:
            raise HTTPException(status_code=400, detail="to_date must be in YYYY-MM-DD format.")
    return start, end


def _apply_filters(query, status: Optional[str], start, end):
    if status:
        if status not in VALID_STATUSES:
            raise HTTPException(status_code=400, detail=f"status must be one of {sorted(VALID_STATUSES)}")
        query = query.where("status", "==", status)
    if start:
        query = query.where("createdAt", ">=", start)
    if end:
        query = query.where("createdAt", "<=", end)
    return query


@router.get("")
def list_orders(
    status: Optional[str] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    limit: int = 50,
):
    """List orders, newest first.
    - ?status=pending|accepted|rejected|completed
    - ?from_date=YYYY-MM-DD&to_date=YYYY-MM-DD restricts to orders placed
      in that date range (inclusive), interpreted as the shop's own IST
      calendar days. Powers the admin app's date filter.
    - ?limit raises the default page size of 50 -- pass a bigger number
      (the admin app uses 5000) when a date filter should return
      everything in range rather than just the latest page.
    """
    db = get_db()
    start, end = _parse_date_range(from_date, to_date)
    query = _apply_filters(db.collection("orders"), status, start, end)
    query = query.order_by("createdAt", direction="DESCENDING").limit(limit)
    return [_serialize(doc) for doc in query.stream()]


@router.get("/export")
def export_orders(status: Optional[str] = None, from_date: Optional[str] = None, to_date: Optional[str] = None):
    """Downloads a CSV of orders in the given range (e.g. the whole of
    last month) for the shop's own records -- the admin app's Orders
    screen "Download" button. Registered ABOVE the /{order_id} route
    below so "/orders/export" doesn't get swallowed by that dynamic path.
    """
    db = get_db()
    start, end = _parse_date_range(from_date, to_date)
    query = _apply_filters(db.collection("orders"), status, start, end)
    query = query.order_by("createdAt", direction="DESCENDING").limit(5000)

    buffer = _io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(
        ["Order ID", "Date & Time (IST)", "Customer Name", "Phone", "Address", "Items", "Total Amount", "Status", "Payment Method"]
    )
    for doc in query.stream():
        order = doc.to_dict() or {}
        created = order.get("createdAt")
        when = created.astimezone(IST).strftime("%Y-%m-%d %H:%M") if hasattr(created, "astimezone") else ""
        items_text = "; ".join(f"{i.get('name', '')} x{i.get('quantity', 0)}" for i in order.get("items", []))
        location = order.get("location") or {}
        writer.writerow(
            [
                doc.id,
                when,
                order.get("customerName", ""),
                order.get("customerPhone", ""),
                location.get("address", ""),
                items_text,
                order.get("totalAmount", ""),
                order.get("status", ""),
                order.get("paymentMethod") or "",
            ]
        )

    name_bits = "orders"
    if from_date:
        name_bits += f"_{from_date}"
    if to_date:
        name_bits += f"_to_{to_date}"

    buffer.seek(0)
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{name_bits}.csv"'},
    )


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
    Accept / reject / complete an order. Also pushes a notification to the
    customer's saved FCM token the moment the status changes — this used
    to be a Firebase Cloud Function (`onOrderUpdated` in
    bamas/functions/index.js), but that needs Firebase's paid Blaze plan,
    so it's done here instead (Admin SDK push sends are free on any plan).
    """
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"status must be one of {sorted(VALID_STATUSES)}")

    db = get_db()
    ref = db.collection("orders").document(order_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Order not found.")

    ref.update({"status": body.status, "updatedAt": datetime.now(timezone.utc)})
    updated = ref.get()
    order = updated.to_dict() or {}

    token = order.get("fcmToken")
    notif = STATUS_NOTIFICATIONS.get(body.status)
    if token and notif:
        title, message_body = notif
        messaging = get_messaging()
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(title=title, body=message_body),
                    data={"type": "order_status", "orderId": order_id, "status": body.status},
                    android=messaging.AndroidConfig(priority="high"),
                )
            )
        except Exception:
            # A failed push shouldn't undo the status change that already
            # happened above.
            pass

    return _serialize(updated)


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


@public_router.post("")
def create_order(body: OrderCreate):
    """Places a new order — called by the customer app instead of writing
    to Firestore directly. Writes the order, THEN pushes a "new order"
    notification to the admin app's `admin_orders` FCM topic in the same
    request. This is what used to be the `onOrderCreated` Cloud Function;
    doing it here means the shop doesn't need Firebase's paid Blaze plan
    just to get notified of new orders."""
    db = get_db()
    data = {
        "items": [item.model_dump() for item in body.items],
        "totalAmount": body.totalAmount,
        "customerName": body.customerName,
        "customerPhone": body.customerPhone,
        "location": {"address": body.address, "lat": body.lat, "lng": body.lng},
        "status": "pending",
        "paymentMethod": None,
        "paymentConfirmedByCustomer": False,
        "fcmToken": body.fcmToken,
        "userId": body.userId,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    ref = db.collection("orders").document()
    ref.set(data)

    item_count = sum((item.quantity or 0) for item in body.items)
    try:
        messaging = get_messaging()
        messaging.send(
            messaging.Message(
                topic="admin_orders",
                notification=messaging.Notification(
                    title="New order received",
                    body=f"{body.customerName or 'A customer'} • {item_count} item(s) • ₹{body.totalAmount}",
                ),
                data={"type": "new_order", "orderId": ref.id},
                android=messaging.AndroidConfig(priority="high"),
            )
        )
    except Exception:
        # Don't block the order from being placed just because the push
        # failed — the admin app's order list will still show it.
        pass

    return _serialize(ref.get())
