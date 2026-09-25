"""
Full deployment self-check. Run on the server:
    cd ~/bamasandstore8 && venv/bin/python -u deploy/selfcheck.py

Checks EVERYTHING the backend and the migration need, in one pass, so
problems surface together instead of one at a time.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

results = []


def check(label, fn):
    print("  %-34s" % (label + " ..."), end="", flush=True)
    t = time.time()
    try:
        detail = fn()
        results.append((True, label))
        print(" PASS  %s" % detail, flush=True)
        return True
    except Exception as e:
        results.append((False, label))
        print(" FAIL  %s: %s" % (type(e).__name__, str(e)[:170]), flush=True)
        return False


try:
    from app.config import settings
except Exception as e:
    print("FATAL: cannot load settings:", e)
    sys.exit(1)

print("=" * 78, flush=True)
print("  bamasandstore8 backend self-check", flush=True)
print("=" * 78, flush=True)


def env_ok():
    # firebase_web_api_key is intentionally absent: Firebase Auth was
    # removed, so nothing needs it any more.
    missing = [n for n in ("mongo_uri", "s3_bucket_name", "jwt_secret",
                           "admin_password_hash", "admin_username",
                           "backup_secret_key")
               if not getattr(settings, n, "")]
    if missing:
        raise RuntimeError("empty: " + ", ".join(missing))
    return "all values present"


def key_file():
    p = settings.firebase_service_account_path
    if not os.path.exists(p):
        raise FileNotFoundError("no key at " + p)
    d = json.load(open(p))
    kid = d.get("private_key_id", "")
    return "id %s...%s  (%s)" % (kid[:10], kid[-6:], d.get("client_email", "?"))


def key_live():
    """Exchanges the key with Google. Catches revoked/rotated keys."""
    from google.oauth2 import service_account
    import google.auth.transport.requests
    c = service_account.Credentials.from_service_account_file(
        settings.firebase_service_account_path,
        scopes=["https://www.googleapis.com/auth/datastore"])
    c.refresh(google.auth.transport.requests.Request())
    return "Google ACCEPTED this key"


def clock_ok():
    """Big clock skew breaks JWT signing, which looks like an auth failure."""
    import email.utils
    import httpx
    r = httpx.get("https://oauth2.googleapis.com/", timeout=15)
    server_time = email.utils.parsedate_to_datetime(r.headers["Date"]).timestamp()
    skew = abs(time.time() - server_time)
    if skew > 60:
        raise RuntimeError("clock is off by %.0f seconds - this breaks auth" % skew)
    return "clock within %.0fs of Google" % skew


def firestore_read():
    """The exact call the migration makes."""
    import httpx
    from google.oauth2 import service_account
    import google.auth.transport.requests
    c = service_account.Credentials.from_service_account_file(
        settings.firebase_service_account_path,
        scopes=["https://www.googleapis.com/auth/datastore"])
    c.refresh(google.auth.transport.requests.Request())
    counts = []
    for coll in ("categories", "menuItems", "orders"):
        url = ("https://firestore.googleapis.com/v1/projects/%s/databases/(default)"
               "/documents/%s?pageSize=3" % (c.project_id, coll))
        r = httpx.get(url, headers={"Authorization": "Bearer " + c.token}, timeout=60)
        if r.status_code != 200:
            raise RuntimeError("%s -> HTTP %d %s" % (coll, r.status_code, r.text[:100]))
        counts.append("%s=%d+" % (coll, len(r.json().get("documents", []))))
    return "Firestore readable (" + ", ".join(counts) + ")"


def mongo_ok():
    from app.mongo_client import get_db
    db = get_db()
    db.command("ping")
    c = {n: db[n].count_documents({}) for n in sorted(db.list_collection_names())}
    return ("connected, EMPTY (pre-migration)" if not c
            else "connected: " + ", ".join("%s=%d" % kv for kv in c.items()))


def s3_ok():
    import boto3
    c = boto3.client("s3", region_name=settings.aws_region)
    r = c.list_objects_v2(Bucket=settings.s3_bucket_name)
    creds = boto3.Session().get_credentials()
    return "bucket '%s' OK, %d objects, creds via %s" % (
        settings.s3_bucket_name, r.get("KeyCount", 0),
        getattr(creds, "method", "?") if creds else "NONE")


def s3_write():
    """Actually write and delete an object - proves the IAM role can WRITE, not just list."""
    import boto3
    c = boto3.client("s3", region_name=settings.aws_region)
    k = "_selfcheck/probe.txt"
    c.put_object(Bucket=settings.s3_bucket_name, Key=k, Body=b"ok")
    c.delete_object(Bucket=settings.s3_bucket_name, Key=k)
    return "write + delete permitted"


def api_ok():
    import httpx
    r = httpx.get("http://127.0.0.1:8000/health", timeout=10)
    return "uvicorn responding: %s" % r.text.strip()


check("1. .env values", env_ok)
check("2. Firebase key file", key_file)
check("3. server clock", clock_ok)
check("4. Firebase key valid at Google", key_live)
check("5. Firestore readable (REST)", firestore_read)
check("6. MongoDB", mongo_ok)
check("7. S3 read", s3_ok)
check("8. S3 write", s3_write)
check("9. backend API", api_ok)

print("=" * 78, flush=True)
bad = [l for ok, l in results if not ok]
if bad:
    print("  %d of %d FAILED: %s" % (len(bad), len(results), ", ".join(bad)), flush=True)
    print("  Fix these before relying on the backend.", flush=True)
    sys.exit(1)
print("  ALL %d CHECKS PASSED." % len(results), flush=True)
