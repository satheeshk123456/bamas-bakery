"""
One-time migration to multi-branch. Run on the server:

    cd ~/bamasandstore8 && venv/bin/python -u deploy/migrate_branches.py           # dry run
    cd ~/bamasandstore8 && venv/bin/python -u deploy/migrate_branches.py --write   # apply

WHY THIS IS NOT OPTIONAL
Every existing menu item and order was written before branches existed, so
none of them has a branchId. The moment the branch-aware customer app starts
sending ?branchId=..., those items match nothing and the menu looks empty --
and every old order becomes invisible to every branch manager. This script
files all of them under the original shop, turned into "branch #1".

It is safe to re-run: documents that already have a branchId are left alone,
and the default branch is only created once.
"""
import argparse
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings  # noqa: E402
from app.mongo_client import get_db  # noqa: E402
from app.security import ROLE_SUPER_ADMIN  # noqa: E402

parser = argparse.ArgumentParser()
parser.add_argument("--write", action="store_true", help="actually apply the changes")
parser.add_argument("--branch-name", default=None, help="name for the default branch")
args = parser.parse_args()

DRY = not args.write
tag = "[dry run]" if DRY else "[writing]"

db = get_db()
print("=" * 70, flush=True)
print("  Bama's -- migrate to multi-branch   %s" % tag, flush=True)
print("=" * 70, flush=True)


# ---------------------------------------------------------------------------
# 1. The default branch, built from the shop's existing settings
# ---------------------------------------------------------------------------
shop = db.shopSettings.find_one({"_id": "main"}) or {}
existing = db.branches.find_one(sort=[("sortOrder", 1)])

if existing is not None:
    branch_id = str(existing["_id"])
    print("1. default branch      ALREADY EXISTS  %s (%s)" % (existing.get("name"), branch_id), flush=True)
else:
    name = args.branch_name or shop.get("shopName") or "Main Branch"
    doc = {
        "name": name,
        "address": shop.get("address", ""),
        "contactPhone": shop.get("contactPhone", ""),
        "upiId": shop.get("upiId", ""),
        # The QR is an S3 KEY, not a URL -- copying the key is correct, the
        # same object is simply referenced from the branch as well.
        "gpayQrUrl": shop.get("gpayQrUrl", ""),
        "imageUrl": "",
        "isOpen": bool(shop.get("isOpen", True)),
        "isActive": True,
        "sortOrder": 1,
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    }
    if DRY:
        branch_id = "<new-branch-id>"
        print("1. default branch      WOULD CREATE    %r" % name, flush=True)
    else:
        branch_id = str(db.branches.insert_one(doc).inserted_id)
        print("1. default branch      CREATED         %s (%s)" % (name, branch_id), flush=True)


# ---------------------------------------------------------------------------
# 2. Backfill menu items and orders
# ---------------------------------------------------------------------------
def backfill(collection_name: str) -> None:
    coll = db[collection_name]
    missing = coll.count_documents({"$or": [{"branchId": {"$exists": False}}, {"branchId": None}]})
    total = coll.count_documents({})
    if missing == 0:
        print("2. %-18s nothing to do   (%d already tagged)" % (collection_name, total), flush=True)
        return
    if DRY:
        print("2. %-18s WOULD TAG       %d of %d" % (collection_name, missing, total), flush=True)
        return
    result = coll.update_many(
        {"$or": [{"branchId": {"$exists": False}}, {"branchId": None}]},
        {"$set": {"branchId": branch_id}},
    )
    print("2. %-18s TAGGED          %d of %d" % (collection_name, result.modified_count, total), flush=True)


backfill("menuItems")
backfill("orders")


# ---------------------------------------------------------------------------
# 3. Promote the .env admin into a real admins document
# ---------------------------------------------------------------------------
# The .env pair keeps working either way (app/security.py falls back to it),
# but once it exists as a document the owner can be renamed, deactivated or
# have their password reset from the admin app like anybody else.
username = (settings.admin_username or "").strip().lower()
if not username:
    print("3. admins             SKIPPED         ADMIN_USERNAME is empty in .env", flush=True)
elif db.admins.find_one({"username": username}) is not None:
    print("3. admins             ALREADY EXISTS  %s" % username, flush=True)
elif not settings.admin_password_hash:
    print("3. admins             SKIPPED         ADMIN_PASSWORD_HASH is empty in .env", flush=True)
elif DRY:
    print("3. admins             WOULD CREATE    %s as %s" % (username, ROLE_SUPER_ADMIN), flush=True)
else:
    db.admins.insert_one(
        {
            "username": username,
            "name": "Owner",
            "role": ROLE_SUPER_ADMIN,
            "branchId": None,
            # Re-uses the hash already in .env -- the password does not change.
            "passwordHash": settings.admin_password_hash,
            "isActive": True,
            "createdAt": datetime.now(timezone.utc),
            "updatedAt": datetime.now(timezone.utc),
        }
    )
    print("3. admins             CREATED         %s as %s" % (username, ROLE_SUPER_ADMIN), flush=True)


# ---------------------------------------------------------------------------
# 4. Indexes
# ---------------------------------------------------------------------------
# Without these, every branch-filtered menu load and order list is a full
# collection scan. Cheap now, painful once there are a few thousand orders.
if DRY:
    print("4. indexes            WOULD CREATE    menuItems.branchId, orders.(branchId,createdAt), admins.username", flush=True)
else:
    db.menuItems.create_index("branchId")
    db.orders.create_index([("branchId", 1), ("createdAt", -1)])
    db.admins.create_index("username", unique=True)
    db.branches.create_index("sortOrder")
    print("4. indexes            CREATED", flush=True)


print("=" * 70, flush=True)
if DRY:
    print("  Nothing was written. Re-run with --write to apply.", flush=True)
else:
    print("  Done. Default branch id: %s" % branch_id, flush=True)
    print("  Next: point the admin app's manager logins at /admins, and have", flush=True)
    print("  each manager's phone subscribe to  branch_%s_managers" % branch_id, flush=True)
print("=" * 70, flush=True)
