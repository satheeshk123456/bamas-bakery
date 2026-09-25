"""
Print every staff login in the database -- who exists, what role, which
branch, active or not.

    cd ~/bamasandstore8 && venv/bin/python -u deploy/list_admins.py

Read-only: it writes nothing and prints no password or hash. Use it to
answer "does this login already exist?" before reaching for
deploy/create_admin.py, and to see at a glance which logins the developer
made and which ones an admin made.

The login in the backend's .env (ADMIN_USERNAME) is NOT in this list
unless it has also been written into the admins collection -- which is
what deploy/migrate_branches.py does. That is the whole point of the
"in .env only" line at the bottom: an .env login still works, but it has
no role and no branch of its own, so it cannot appear here.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings  # noqa: E402
from app.mongo_client import get_db  # noqa: E402

db = get_db()

branch_names = {str(b["_id"]): b.get("name", "?") for b in db.branches.find()}

rows = list(db.admins.find().sort("role", 1))
if not rows:
    print("No logins in the admins collection at all.")
    print("Run deploy/migrate_branches.py --write, then deploy/create_admin.py.")
else:
    print("%-30s %-15s %-18s %-8s %s" % ("USERNAME", "ROLE", "BRANCH", "ACTIVE", "CREATED BY"))
    print("-" * 95)
    for a in rows:
        branch = branch_names.get(str(a.get("branchId") or ""), "-" if not a.get("branchId") else "(missing)")
        print("%-30s %-15s %-18s %-8s %s" % (
            a.get("username", "?"),
            a.get("role", "?"),
            branch,
            "yes" if a.get("isActive", True) else "NO",
            a.get("createdByName") or a.get("createdBy") or "-",
        ))

print()
env_user = (settings.admin_username or "").strip().lower()
if env_user:
    in_db = db.admins.find_one({"username": env_user}) is not None
    print("Login in .env : %s  -> %s" % (
        env_user,
        "also in the admins collection above" if in_db
        else "in .env ONLY (works as super_admin by fallback, but cannot be edited from the app)",
    ))

print()
print("Branches: %s" % (", ".join("%s (%s)" % (n, i) for i, n in branch_names.items()) or "none yet"))
