"""
One-time migration: Firestore  ->  MongoDB + S3.

Run ON THE EC2 SERVER (it needs the Mongo connection, the IAM role for S3,
and serviceAccountKey.json for Firestore):

    cd ~/bamasandstore8
    venv/bin/python deploy/migrate_firestore.py            # dry run, writes nothing
    venv/bin/python deploy/migrate_firestore.py --write    # actually migrate

Firestore is only ever READ. Nothing there is modified or deleted.

What it does:
  * copies all 8 collections into MongoDB
  * every base64 image stored in Firestore is decoded, uploaded to S3,
    and replaced by its S3 object key (which is what the backend expects)
  * generates new MongoDB ObjectIds where the backend requires them, and
    remaps menuItems.categoryId / orders.items[].itemId to the new ids
  * keeps shopSettings under _id "main" and users under their Firebase uid
"""
import argparse
import base64
import os
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId

from app.config import settings
from app.mongo_client import get_db

# collections whose ids the backend looks up with ObjectId(...)
OBJECTID_COLLECTIONS = ["categories", "menuItems", "offers", "orders", "reviews", "enquiries"]
# S3 key prefix per collection, matching what the running backend uses
S3_PREFIX = {
    "categories": "categories",
    "menuItems": "items",
    "offers": "offers",
    "shopSettings": "shop",
}
MIME_EXT = {
    "image/jpeg": ".jpg", "image/jpg": ".jpg", "image/png": ".png",
    "image/webp": ".webp", "image/gif": ".gif",
}


# ---------------------------------------------------------------------------
# Firestore over plain HTTPS.
# The gRPC transport used by firebase_admin.firestore hangs on this EC2 box,
# so we talk to the Firestore REST API directly instead. Same data, same
# service-account credentials, just a transport that actually works here.
# ---------------------------------------------------------------------------
FS_PAGE_SIZE = 20   # base64 images make documents large; keep pages small


def _fs_credentials():
    from google.oauth2 import service_account
    import google.auth.transport.requests
    creds = service_account.Credentials.from_service_account_file(
        settings.firebase_service_account_path,
        scopes=["https://www.googleapis.com/auth/datastore"],
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds


def _decode(v):
    """Convert one Firestore REST typed value into a plain Python value."""
    if "stringValue" in v:
        return v["stringValue"]
    if "integerValue" in v:
        return int(v["integerValue"])
    if "doubleValue" in v:
        return float(v["doubleValue"])
    if "booleanValue" in v:
        return v["booleanValue"]
    if "timestampValue" in v:
        return datetime.fromisoformat(v["timestampValue"].replace("Z", "+00:00"))
    if "nullValue" in v:
        return None
    if "mapValue" in v:
        return {k: _decode(x) for k, x in (v["mapValue"].get("fields") or {}).items()}
    if "arrayValue" in v:
        return [_decode(x) for x in (v["arrayValue"].get("values") or [])]
    if "geoPointValue" in v:
        return v["geoPointValue"]
    if "referenceValue" in v:
        return v["referenceValue"]
    if "bytesValue" in v:
        return v["bytesValue"]
    return None


def read_collection(name, creds):
    """Read every document of a Firestore collection over HTTPS. Returns [(id, data)]."""
    import httpx
    base = ("https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s"
            % (creds.project_id, name))
    out, page = [], None
    with httpx.Client(timeout=180) as client:
        while True:
            url = base + "?pageSize=%d" % FS_PAGE_SIZE
            if page:
                url += "&pageToken=" + page
            r = client.get(url, headers={"Authorization": "Bearer " + creds.token})
            if r.status_code == 404:
                return []          # collection does not exist -> treat as empty
            r.raise_for_status()
            body = r.json()
            for d in body.get("documents", []):
                doc_id = d["name"].rsplit("/", 1)[-1]
                out.append((doc_id, {k: _decode(v) for k, v in (d.get("fields") or {}).items()}))
            page = body.get("nextPageToken")
            if not page:
                return out


stats = {"docs": 0, "images": 0, "image_bytes": 0, "skipped_urls": 0, "errors": []}


def is_data_uri(v):
    return isinstance(v, str) and v.startswith("data:image/") and ";base64," in v


def is_http_url(v):
    return isinstance(v, str) and (v.startswith("http://") or v.startswith("https://"))


def upload_data_uri(s3, data_uri, prefix, doc_id, dry_run):
    """Decode a base64 data URI and upload to S3. Returns the S3 object key."""
    header, b64 = data_uri.split(";base64,", 1)
    mime = header[5:]
    ext = MIME_EXT.get(mime, ".jpg")
    raw = base64.b64decode(b64)
    key = "%s/%s-%s%s" % (prefix, doc_id, uuid.uuid4().hex[:8], ext)
    stats["images"] += 1
    stats["image_bytes"] += len(raw)
    if not dry_run:
        s3.put_object(Bucket=settings.s3_bucket_name, Key=key, Body=raw, ContentType=mime)
    return key


def convert_value(s3, value, prefix, doc_id, dry_run):
    """Recursively convert base64 images inside a value into S3 keys."""
    if is_data_uri(value):
        return upload_data_uri(s3, value, prefix, doc_id, dry_run)
    if is_http_url(value):
        stats["skipped_urls"] += 1
        return value
    if isinstance(value, dict):
        return {k: convert_value(s3, v, prefix, doc_id, dry_run) for k, v in value.items()}
    if isinstance(value, list):
        return [convert_value(s3, v, prefix, doc_id, dry_run) for v in value]
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if type(value).__name__ in ("DocumentReference", "GeoPoint"):
        return str(value)
    return value


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="actually write (default is a dry run)")
    ap.add_argument("--force", action="store_true", help="allow writing into non-empty collections")
    args = ap.parse_args()
    dry = not args.write

    print("=" * 68, flush=True)
    print("  Firestore -> MongoDB + S3 migration   %s" % ("[DRY RUN - nothing written]" if dry else "[WRITING]"), flush=True)
    print("=" * 68, flush=True)

    import boto3

    print("  authenticating with Firestore (REST)...", flush=True)
    creds = _fs_credentials()
    print("    project: %s" % creds.project_id, flush=True)
    print("  connecting to MongoDB...", flush=True)
    db = get_db()
    db.command("ping")
    print("  connecting to S3...", flush=True)
    s3 = boto3.client("s3", region_name=settings.aws_region)
    print("  all connections OK, reading collections", flush=True)
    print("", flush=True)

    # safety: refuse to overwrite existing data unless forced
    if not dry:
        existing = {c: db[c].count_documents({}) for c in
                    OBJECTID_COLLECTIONS + ["shopSettings", "users"]}
        non_empty = {k: v for k, v in existing.items() if v}
        if non_empty and not args.force:
            print("REFUSING TO RUN: these collections already have data:")
            for k, v in non_empty.items():
                print("   %-14s %d documents" % (k, v))
            print("\nRe-run with --force to DELETE and replace them, or migrate into an empty database.")
            sys.exit(1)
        if non_empty and args.force:
            for k in non_empty:
                db[k].delete_many({})
            print("--force: cleared %s\n" % ", ".join(non_empty))

    id_map = {}   # (collection, firestore_id) -> new mongo id as str

    # pass 1: categories and menuItems first so ids exist for remapping
    order = ["categories", "menuItems", "offers", "shopSettings", "orders", "users", "reviews", "enquiries"]
    pending = {}

    for coll in order:
        print("  reading %-14s ..." % coll, end="", flush=True)
        try:
            docs = read_collection(coll, creds)
        except Exception as e:
            stats["errors"].append("read %s: %s" % (coll, e))
            print(" READ FAILED: %s" % e, flush=True)
            continue

        rows = []
        for doc_id, data in docs:
            data = dict(data or {})
            prefix = S3_PREFIX.get(coll, coll.lower())
            try:
                data = {k: convert_value(s3, v, prefix, doc_id, dry) for k, v in data.items()}
            except Exception as e:
                stats["errors"].append("%s/%s image: %s" % (coll, doc_id, e))

            if coll == "shopSettings":
                new_id = "main"
            elif coll == "users":
                new_id = doc_id         # Firebase uid
            else:
                new_id = ObjectId()
                id_map[(coll, doc_id)] = str(new_id)

            data["_id"] = new_id
            rows.append(data)
            stats["docs"] += 1

        pending[coll] = rows
        print(" %d documents, %d images so far" % (len(rows), stats["images"]), flush=True)

    # pass 2: remap references to the new ids
    remapped = 0
    for row in pending.get("menuItems", []):
        old = row.get("categoryId")
        if old and ("categories", old) in id_map:
            row["categoryId"] = id_map[("categories", old)]
            remapped += 1
    for row in pending.get("orders", []):
        for item in row.get("items", []) or []:
            if isinstance(item, dict):
                old = item.get("itemId")
                if old and ("menuItems", old) in id_map:
                    item["itemId"] = id_map[("menuItems", old)]
                    remapped += 1

    print("\n  references remapped to new ids: %d" % remapped)
    print("  images found: %d (%.1f MB)" % (stats["images"], stats["image_bytes"] / 1048576.0))
    if stats["skipped_urls"]:
        print("  NOTE: %d fields already held http URLs and were left unchanged" % stats["skipped_urls"])

    # pass 3: write
    if not dry:
        for coll, rows in pending.items():
            if rows:
                db[coll].insert_many(rows)
        print("\n  written to MongoDB.")

    print("=" * 68)
    print("  total documents: %d" % stats["docs"])
    if stats["errors"]:
        print("  ERRORS (%d):" % len(stats["errors"]))
        for e in stats["errors"][:20]:
            print("    - %s" % e)
    if dry:
        print("\n  This was a DRY RUN. Nothing was written to MongoDB or S3.")
        print("  Re-run with --write to perform the migration.")
    else:
        print("\n  MIGRATION COMPLETE.")
    print("=" * 68)


if __name__ == "__main__":
    main()
