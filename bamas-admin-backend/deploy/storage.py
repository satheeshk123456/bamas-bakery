"""
Storage report: disk, MongoDB and S3.
    cd ~/bamasandstore8 && venv/bin/python -u deploy/storage.py
Read-only -- nothing is modified.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings
from app.mongo_client import get_db


def human(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024:
            return "%.1f %s" % (n, unit)
        n /= 1024.0
    return "%.1f PB" % n


def bar(pct, width=30):
    filled = int(round(pct / 100.0 * width))
    return "[" + "#" * filled + "." * (width - filled) + "]"


print("=" * 72)
print("  STORAGE REPORT")
print("=" * 72)

# ---- disk ----
total, used, free = shutil.disk_usage("/")
pct = used / total * 100
print("\n  DISK (the EC2 volume)")
print("    %s %.1f%% used" % (bar(pct), pct))
print("    used %s of %s   -   %s free" % (human(used), human(total), human(free)))
if pct > 80:
    print("    WARNING: over 80%% full. Clear old logs/caches or grow the volume.")

# ---- what is using it ----
print("\n  LARGEST DIRECTORIES")
try:
    out = subprocess.run(
        "sudo du -xh --max-depth=2 / 2>/dev/null | sort -rh | head -10",
        shell=True, capture_output=True, text=True, timeout=90).stdout.strip()
    for line in out.splitlines():
        print("    " + line)
except Exception as e:
    print("    (could not measure: %s)" % e)

# ---- mongodb ----
print("\n  MONGODB (%s)" % settings.mongo_db_name)
try:
    db = get_db()
    stats = db.command("dbStats")
    print("    data %s   indexes %s   total %s" % (
        human(stats.get("dataSize", 0)),
        human(stats.get("indexSize", 0)),
        human(stats.get("storageSize", 0) + stats.get("indexSize", 0))))
    print("    %-16s %10s %12s" % ("collection", "documents", "size"))
    for name in sorted(db.list_collection_names()):
        cs = db.command("collStats", name)
        print("    %-16s %10d %12s" % (name, cs.get("count", 0), human(cs.get("size", 0))))
except Exception as e:
    print("    FAILED: %s" % e)

# ---- s3 ----
print("\n  S3 (%s)" % settings.s3_bucket_name)
try:
    import boto3
    s3 = boto3.client("s3", region_name=settings.aws_region)
    total_bytes, count, prefixes = 0, 0, {}
    token = None
    while True:
        kw = {"Bucket": settings.s3_bucket_name}
        if token:
            kw["ContinuationToken"] = token
        resp = s3.list_objects_v2(**kw)
        for obj in resp.get("Contents", []):
            total_bytes += obj["Size"]
            count += 1
            p = obj["Key"].split("/")[0]
            prefixes[p] = prefixes.get(p, 0) + obj["Size"]
        token = resp.get("NextContinuationToken")
        if not token:
            break
    print("    %d objects, %s total" % (count, human(total_bytes)))
    for p, b in sorted(prefixes.items(), key=lambda kv: -kv[1]):
        print("      %-14s %s" % (p + "/", human(b)))
    # S3 free tier is 5 GB for the first 12 months; after that it is paid
    print("    (S3 is billed by usage - no fixed limit to run out of)")
except Exception as e:
    print("    FAILED: %s" % e)

print("\n" + "=" * 72)
