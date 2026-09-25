import csv
import io as _io
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from ..firebase_client import get_messaging
from ..mongo_client import get_db
from ..mongo_utils import oid, serialize
from ..models import OrderCreate, OrderStatusUpdate
from ..security import (
    CurrentAdmin,
    assert_can_touch_branch,
    branch_scope,
    get_current_admin,
)

# The shop's own local day, used to interpret ?from_date/?to_date on the
# date-filter and CSV-export endpoints below. Fixed offset is exact for
# India (no DST), so this needs no extra timezone-data dependency.
IST = timezone(timedelta(hours=5, minutes=30))

router = APIRouter(prefix="/orders", tags=["orders"], dependencies=[Depends(get_current_admin)])

# Separate, unauthenticated router for the one endpoint the customer app
# calls directly (placing an order) -- every other order route needs an
# admin login, this one doesn't.
public_router = APIRouter(prefix="/orders", tags=["orders-public"])

VALID_STATUSES = {"pending", "accepted", "rejected", "completed"}

STATUS_NOTIFICATIONS = {
    "accepted": ("Order confirmed!", "Your order has been accepted. Open the app to pay online."),
    "rejected": ("Order could not be confirmed", "Sorry, we could not confirm your order. Please call the shop."),
    "completed": ("Order completed", "Thanks for ordering with us!"),
}


# Every manager's phone subscribes to its own branch topic; the owner's
# phone stays on "admin_orders" and so keeps seeing every branch. The
# already-published admin app only knows admin_orders, which is why the
# global topic is still sent to below -- dropping it would silence the
# app that is live right now.
def _branch_topic(branch_id: str | None) -> str | None:
    if not branch_id:
        return None
    # FCM topic names allow [a-zA-Z0-9-_.~%]+ ; a Mongo ObjectId hex string
    # is safely inside that set.
    return f"branch_{branch_id}_managers"


def _default_branch_id(db) -> str | None:
    """Where an order goes when the customer app did not name a branch.

    The published customer app has no branch picker, so without this every
    order it places would be branch-less -- invisible to every manager and
    only findable by the owner. Falls back to the lowest-sorted active
    branch, which after deploy/migrate_branches.py is the original shop.
    """
    doc = db.branches.find_one({"isActive": {"$ne": False}}, sort=[("sortOrder", 1)])
    return str(doc["_id"]) if doc else None


def _assert_accepting_orders(db, branch_id: str | None) -> None:
    """Refuse a new order while the shop, or that branch, is switched off.

    TWO switches decide this, and CLOSED WINS:

        shopSettings.isOpen   the master switch in the admin app's
                              Settings screen -- shuts every branch
        branches[].isOpen     shuts one branch, others keep trading

    A missing flag counts as open, so a shop that has never touched
    either switch keeps taking orders exactly as it does today.

    This has to live here, not only in the customer app: the version
    already on customers' phones has no such check at all, and an app
    can never be trusted to enforce a rule the shop depends on. The
    status code is 409 (conflict with current state) rather than 403,
    because nothing is wrong with the customer -- the shop is shut.
    """
    shop = db.shopSettings.find_one({"_id": "main"}) or {}
    if shop.get("isOpen") is False:
        raise HTTPException(
            status_code=409,
            detail="The shop is closed right now, so new orders are paused. Please try again later.",
        )

    if branch_id:
        branch = db.branches.find_one({"_id": oid(branch_id)}) or {}
        if branch.get("isOpen") is False:
            name = (branch.get("name") or "").strip() or "This branch"
            raise HTTPException(
                status_code=409,
                detail=f"{name} is closed right now, so new orders are paused. Please try again later.",
            )


def _parse_date_range(from_date: Optional[str], to_date: Optional[str]):
    """Turns ?from_date=YYYY-MM-DD / ?to_date=YYYY-MM-DD into timezone-aware
    datetimes covering that whole IST calendar day (inclusive on both
    ends) -- e.g. from_date=to_date=2026-08-01 covers all of August 1st
    in the shop's own local time, not UTC."""
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


def _build_filter(status: Optional[str], start, end) -> dict:
    filt: dict = {}
    if status:
        if status not in VALID_STATUSES:
            raise HTTPException(status_code=400, detail=f"status must be one of {sorted(VALID_STATUSES)}")
        filt["status"] = status
    created_filter: dict = {}
    if start:
        created_filter["$gte"] = start
    if end:
        created_filter["$lte"] = end
    if created_filter:
        filt["createdAt"] = created_filter
    return filt


@router.get("")
def list_orders(
    status: Optional[str] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    limit: int = 50,
    branchId: Optional[str] = None,
    admin: CurrentAdmin = Depends(get_current_admin),
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
    filt = _build_filter(status, start, end)
    # The branch restriction is applied to the QUERY, not to the response,
    # so a manager cannot page past it. An owner/super admin gets every
    # branch unless they explicitly ask for one.
    filt.update(branch_scope(admin, branchId))
    docs = db.orders.find(filt).sort("createdAt", -1).limit(limit)
    return [serialize(d) for d in docs]


@router.get("/export")
def export_orders(
    status: Optional[str] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    branchId: Optional[str] = None,
    admin: CurrentAdmin = Depends(get_current_admin),
):
    """Downloads a CSV of orders in the given range (e.g. the whole of
    last month) for the shop's own records. Registered ABOVE the
    /{order_id} route below so "/orders/export" doesn't get swallowed by
    that dynamic path."""
    db = get_db()
    start, end = _parse_date_range(from_date, to_date)
    filt = _build_filter(status, start, end)
    filt.update(branch_scope(admin, branchId))
    docs = db.orders.find(filt).sort("createdAt", -1).limit(5000)

    buffer = _io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(
        ["Order ID", "Date & Time (IST)", "Branch", "Customer Name", "Phone", "Address", "Items", "Total Amount", "Status", "Payment Method"]
    )
    # One lookup, not one per row -- an owner exporting a month across
    # every branch would otherwise hit the database thousands of times.
    branch_names = {str(b["_id"]): b.get("name", "") for b in db.branches.find()}
    for order in docs:
        created = order.get("createdAt")
        when = created.astimezone(IST).strftime("%Y-%m-%d %H:%M") if hasattr(created, "astimezone") else ""
        items_text = "; ".join(f"{i.get('name', '')} x{i.get('quantity', 0)}" for i in order.get("items", []))
        location = order.get("location") or {}
        writer.writerow(
            [
                str(order.get("_id", "")),
                when,
                branch_names.get(order.get("branchId") or "", ""),
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
def get_order(order_id: str, admin: CurrentAdmin = Depends(get_current_admin)):
    """One order in full -- including the customer's phone and delivery
    address, which the branch manager needs to ring them and drop it off.

    assert_can_touch_branch answers 404 (not 403) for another branch's
    order, so a manager cannot even confirm that an id exists elsewhere."""
    db = get_db()
    doc = db.orders.find_one({"_id": oid(order_id)})
    if doc is None:
        raise HTTPException(status_code=404, detail="Order not found.")
    assert_can_touch_branch(admin, doc.get("branchId"))
    return serialize(doc)


@router.patch("/{order_id}/status")
def update_order_status(order_id: str, body: OrderStatusUpdate, admin: CurrentAdmin = Depends(get_current_admin)):
    """
    Accept / reject / complete an order. Also pushes a notification to the
    customer's saved FCM token the moment the status changes -- done here
    (rather than a Firestore-triggered Cloud Function) since that needs
    Firebase's paid Blaze plan and Admin SDK push sends are free either way.
    """
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"status must be one of {sorted(VALID_STATUSES)}")

    db = get_db()
    _id = oid(order_id)
    doc = db.orders.find_one({"_id": _id})
    if doc is None:
        raise HTTPException(status_code=404, detail="Order not found.")
    assert_can_touch_branch(admin, doc.get("branchId"))

    db.orders.update_one({"_id": _id}, {"$set": {"status": body.status, "updatedAt": datetime.now(timezone.utc)}})
    order = db.orders.find_one({"_id": _id})

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

    return serialize(order)


@router.post("/{order_id}/notify-test")
def send_test_notification(order_id: str, admin: CurrentAdmin = Depends(get_current_admin)):
    """Manually re-send the 'new order' push for this order to the
    admin_orders topic -- handy for testing without placing a real order."""
    db = get_db()
    order = db.orders.find_one({"_id": oid(order_id)})
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found.")
    assert_can_touch_branch(admin, order.get("branchId"))
    messaging = get_messaging()
    item_count = sum((i.get("quantity") or 0) for i in order.get("items", []))
    messaging.send(
        messaging.Message(
            topic=_branch_topic(order.get("branchId")) or "admin_orders",
            notification=messaging.Notification(
                title="New order received",
                body=f"{order.get('customerName', 'A customer')} - {item_count} item(s) - Rs.{order.get('totalAmount', '')}",
            ),
            data={"type": "new_order", "orderId": order_id},
            android=messaging.AndroidConfig(priority="high"),
        )
    )
    return {"sent": True}


@public_router.post("")
def create_order(body: OrderCreate):
    """Places a new order -- called by the customer app instead of
    writing to a database directly (MongoDB has no client-side SDK story
    like Firestore did, so this write always goes through the backend
    now). Writes the order, THEN pushes a "new order" notification to
    the admin app's `admin_orders` FCM topic in the same request."""
    db = get_db()
    now = datetime.now(timezone.utc)

    branch_id = body.branchId or _default_branch_id(db)
    if body.branchId and db.branches.find_one({"_id": oid(body.branchId)}) is None:
        raise HTTPException(status_code=400, detail="That branch does not exist.")

    # Checked BEFORE the insert, so a closed shop never ends up with an
    # order it has to go and reject by hand.
    _assert_accepting_orders(db, branch_id)

    data = {
        "branchId": branch_id,
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
        "createdAt": now,
        "updatedAt": now,
    }
    result = db.orders.insert_one(dict(data))
    data["_id"] = result.inserted_id

    item_count = sum((item.quantity or 0) for item in body.items)
    # Two topics, on purpose:
    #   admin_orders              -> the owner, and every already-installed
    #                                admin app, which knows no other topic
    #   branch_<id>_managers      -> only the managers of the branch that
    #                                has to cook and deliver this order
    topics = ["admin_orders"]
    branch_topic = _branch_topic(branch_id)
    if branch_topic:
        topics.append(branch_topic)

    for topic in topics:
        try:
            messaging = get_messaging()
            messaging.send(
                messaging.Message(
                    topic=topic,
                    notification=messaging.Notification(
                        title="New order received",
                        body=f"{body.customerName or 'A customer'} - {item_count} item(s) - Rs.{body.totalAmount}",
                    ),
                    data={
                        "type": "new_order",
                        "orderId": str(result.inserted_id),
                        "branchId": branch_id or "",
                    },
                    android=messaging.AndroidConfig(priority="high"),
                )
            )
        except Exception:
            # Don't block the order from being placed just because the push
            # failed -- the admin app's order list will still show it.
            continue

    return serialize(data)
