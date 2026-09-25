"""List every image field after migration and classify it. Read-only."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.mongo_client import get_db
from app.config import settings

IMG_FIELDS = ["imageUrl", "logoUrl", "heroImageUrl", "gpayQrUrl", "weekendOfferImageUrl"]
db = get_db()
s3keys, urls, empty, odd = [], [], [], []

for coll in ("categories", "menuItems", "offers", "shopSettings"):
    for d in db[coll].find():
        name = d.get("name") or d.get("title") or d.get("shopName") or str(d["_id"])
        for f in IMG_FIELDS:
            v = d.get(f)
            if v is None:
                continue
            if not isinstance(v, str) or v == "":
                empty.append((coll, name, f))
            elif v.startswith("http://") or v.startswith("https://"):
                urls.append((coll, name, f, v))
            elif "/" in v and not v.startswith("data:"):
                s3keys.append((coll, name, f, v))
            else:
                odd.append((coll, name, f, v[:40]))

print("=" * 78)
print("  IMAGE FIELD REPORT")
print("=" * 78)
print("\n  S3 keys (will display correctly): %d" % len(s3keys))
for c, n, f, v in s3keys:
    print("     %-13s %-28s %-22s %s" % (c, n[:28], f, v))
print("\n  HTTP URLs (backend will sign these WRONGLY -> broken image): %d" % len(urls))
for c, n, f, v in urls:
    print("     %-13s %-28s %-22s %s" % (c, n[:28], f, v[:60]))
print("\n  empty/blank (no image set, harmless): %d" % len(empty))
for c, n, f in empty:
    print("     %-13s %-28s %s" % (c, n[:28], f))
if odd:
    print("\n  unrecognised: %d" % len(odd))
    for c, n, f, v in odd:
        print("     %-13s %-28s %-22s %s" % (c, n[:28], f, v))

# verify an S3 key really resolves
if s3keys:
    import boto3
    c3 = boto3.client("s3", region_name=settings.aws_region)
    ok = 0
    for _, _, _, k in s3keys:
        try:
            c3.head_object(Bucket=settings.s3_bucket_name, Key=k); ok += 1
        except Exception as e:
            print("     MISSING IN S3: %s (%s)" % (k, e))
    print("\n  verified present in S3: %d/%d" % (ok, len(s3keys)))
print("=" * 78)
