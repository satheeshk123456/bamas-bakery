"""Diagnose why Firestore reads hang. Run: venv/bin/python -u deploy/diag_firestore.py"""
import os, socket, sys, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def step(label, fn, timeout_note=""):
    print("  %-42s" % (label + " ..."), end="", flush=True)
    t = time.time()
    try:
        r = fn()
        print(" OK  (%.1fs)  %s" % (time.time() - t, r), flush=True)
        return True
    except Exception as e:
        print(" FAIL (%.1fs)  %s: %s" % (time.time() - t, type(e).__name__, str(e)[:150]), flush=True)
        return False

print("=" * 70, flush=True)
print("  Firestore connectivity diagnosis", flush=True)
print("=" * 70, flush=True)

def dns_v4():
    a = socket.getaddrinfo("firestore.googleapis.com", 443, socket.AF_INET)
    return "IPv4: " + a[0][4][0]

def dns_v6():
    a = socket.getaddrinfo("firestore.googleapis.com", 443, socket.AF_INET6)
    return "IPv6: " + a[0][4][0] + "  <-- gRPC may try this first and stall"

def tcp443():
    s = socket.create_connection(("firestore.googleapis.com", 443), timeout=10)
    s.close()
    return "TCP 443 reachable"

def https_get():
    import httpx
    r = httpx.get("https://firestore.googleapis.com/", timeout=15)
    return "HTTP %d" % r.status_code

def token():
    from app.firebase_client import get_firebase_app
    import google.auth, google.auth.transport.requests
    get_firebase_app()
    creds, proj = google.auth.default(scopes=["https://www.googleapis.com/auth/datastore"])
    creds.refresh(google.auth.transport.requests.Request())
    return "auth token obtained for project %s" % proj

def firestore_rest():
    """Read one document over plain HTTPS - bypasses gRPC entirely."""
    import httpx, google.auth, google.auth.transport.requests
    from app.config import settings
    import json
    creds, proj = google.auth.default(scopes=["https://www.googleapis.com/auth/datastore"])
    creds.refresh(google.auth.transport.requests.Request())
    url = ("https://firestore.googleapis.com/v1/projects/%s/databases/(default)"
           "/documents/categories?pageSize=1" % proj)
    r = httpx.get(url, headers={"Authorization": "Bearer " + creds.token}, timeout=30)
    if r.status_code != 200:
        raise RuntimeError("HTTP %d: %s" % (r.status_code, r.text[:120]))
    n = len(r.json().get("documents", []))
    return "REST read worked, got %d document(s)" % n

def firestore_grpc():
    """The call that is hanging - with a hard 45s timeout so it cannot hang forever."""
    from firebase_admin import firestore
    from app.firebase_client import get_firebase_app
    get_firebase_app()
    fs = firestore.client()
    docs = list(fs.collection("categories").stream(timeout=45))
    return "gRPC read worked, got %d document(s)" % len(docs)

step("DNS lookup (IPv4)", dns_v4)
step("DNS lookup (IPv6)", dns_v6)
step("TCP connect to port 443", tcp443)
step("plain HTTPS request", https_get)
step("Google auth token", token)
rest_ok = step("Firestore read over REST (no gRPC)", firestore_rest)
grpc_ok = step("Firestore read over gRPC (45s cap)", firestore_grpc)

print("=" * 70, flush=True)
if rest_ok and not grpc_ok:
    print("  DIAGNOSIS: gRPC is blocked/stalling, but REST works.", flush=True)
    print("  FIX: switch the migration to the REST transport.", flush=True)
elif rest_ok and grpc_ok:
    print("  Both work - the earlier hang was likely just slow. Retry the migration.", flush=True)
elif not rest_ok:
    print("  Firestore is unreachable even over REST - see the failures above.", flush=True)
print("=" * 70, flush=True)
