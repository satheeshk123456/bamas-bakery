"""
Create or update a staff login from the server.

    cd ~/bamasandstore8 && venv/bin/python -u deploy/create_admin.py \
        --username techbachelor@gmail.com --role super_admin --name Developer

The password is asked for interactively so it never lands in the shell
history or in a log. Re-running for an existing username updates that
account's role, name and password rather than creating a duplicate.

This is the ONLY way to create the first developer login: POST /admins
requires an existing developer or admin token, so something has to break
that circle from the server side.
"""
import argparse
import getpass
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.mongo_client import get_db  # noqa: E402
from app.mongo_utils import oid  # noqa: E402
from app.security import ALL_ROLES, ROLE_BRANCH_MANAGER, hash_password  # noqa: E402

parser = argparse.ArgumentParser()
parser.add_argument("--username", required=True, help="the login, e.g. an email address")
parser.add_argument("--role", required=True, choices=list(ALL_ROLES))
parser.add_argument("--name", default="", help="display name shown in the app")
parser.add_argument("--branch-id", default=None, help="required for a branch_manager")
args = parser.parse_args()

db = get_db()
username = args.username.strip().lower()

if args.role == ROLE_BRANCH_MANAGER:
    if not args.branch_id:
        sys.exit("A branch_manager needs --branch-id. Run deploy/migrate_branches.py first if you have no branches yet.")
    if db.branches.find_one({"_id": oid(args.branch_id)}) is None:
        sys.exit("No branch with that id.")
elif args.branch_id:
    sys.exit("Only a branch_manager takes --branch-id.")

password = getpass.getpass("Password (min 8 chars): ")
if len(password) < 8:
    sys.exit("Too short. Nothing was written.")
if password != getpass.getpass("Confirm password: "):
    sys.exit("Passwords did not match. Nothing was written.")

now = datetime.now(timezone.utc)
existing = db.admins.find_one({"username": username})
fields = {
    "name": args.name.strip() or username,
    "role": args.role,
    "branchId": args.branch_id or None,
    "passwordHash": hash_password(password),
    "isActive": True,
    "updatedAt": now,
}

if existing is None:
    fields.update({"username": username, "createdBy": "server", "createdByName": "server", "createdAt": now})
    db.admins.insert_one(fields)
    print("CREATED  %s  (%s)" % (username, args.role), flush=True)
else:
    db.admins.update_one({"_id": existing["_id"]}, {"$set": fields})
    print("UPDATED  %s  (%s)" % (username, args.role), flush=True)

print("Log in from the admin app with this username and password.", flush=True)
