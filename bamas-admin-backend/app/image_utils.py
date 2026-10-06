"""
Image upload handling -- now uploads to S3 instead of base64-encoding
into a database document (that was a Firestore-specific workaround for
staying on Firebase's free plan; on AWS there's no reason not to use S3
directly). Still sniffs the file's real magic bytes rather than trusting
the client-supplied Content-Type header, which has burned this project
before (image_picker's cache path often reports a generic
application/octet-stream).

Stored values are S3 OBJECT KEYS, not full URLs -- the bucket has
"Block All Public Access" on, so every read has to go through
presigned_url() to mint a short-lived signed link, never a stored
permanent URL.
"""
import time
import uuid

import boto3
from fastapi import HTTPException, UploadFile

from .config import settings

# S3 has no per-document size pressure like Firestore's 1 MiB cap did --
# these are just sane upper bounds on a phone photo.
ITEM_IMAGE_MAX_BYTES = 5 * 1024 * 1024
SHOP_IMAGE_MAX_BYTES = 5 * 1024 * 1024

_s3 = None


def _client():
    global _s3
    if _s3 is None:
        _s3 = boto3.client(
            "s3",
            region_name=settings.aws_region,
            aws_access_key_id=settings.aws_access_key_id or None,
            aws_secret_access_key=settings.aws_secret_access_key or None,
        )
    return _s3


def _sniff(raw: bytes):
    if raw[:3] == b"\xff\xd8\xff":
        return "image/jpeg", ".jpg"
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png", ".png"
    if raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp", ".webp"
    return None, None


async def upload_image(file: UploadFile, prefix: str, doc_id: str, max_bytes: int = ITEM_IMAGE_MAX_BYTES) -> str:
    """Uploads to S3, returns the OBJECT KEY. Callers store this key in
    Mongo and turn it into a fresh presigned_url() at read time -- never
    store a presigned URL itself, it expires."""
    if not settings.s3_bucket_name:
        raise HTTPException(status_code=503, detail="Server is missing S3_BUCKET_NAME.")
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="The uploaded file was empty.")
    if len(raw) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"Image is too large ({len(raw)//1024} KB). Please use a photo under {max_bytes//1024} KB.",
        )
    content_type, ext = _sniff(raw)
    if content_type is None:
        raise HTTPException(status_code=400, detail="Unsupported image type. Please upload a JPEG, PNG, or WEBP photo.")
    key = f"{prefix}/{doc_id}-{uuid.uuid4().hex[:8]}{ext}"
    _client().put_object(Bucket=settings.s3_bucket_name, Key=key, Body=raw, ContentType=content_type)
    return key


# A presigned URL embeds a signature and an expiry, so signing the same key
# twice produces two different strings. The app caches images by URL, so a
# changing URL meant every menu refresh re-downloaded every photo. Handing
# back the SAME url until it is close to expiring makes that cache work.
_url_cache: dict[str, tuple[str, float]] = {}
_URL_CACHE_SECONDS = 45 * 60          # re-sign well before the 60 min expiry


def presigned_url(key: str | None, expires_in: int = 3600) -> str:
    """Turns a stored S3 key into a short-lived signed link. Safe to call
    with an empty/None key (returns '') -- most imageUrl fields are
    optional."""
    if not key:
        return ""
    # Not every stored value is an S3 object. Signing these would corrupt
    # them into broken links, so they are passed through untouched:
    #   http(s)://...  external images (e.g. stock photos on seeded items)
    #   assets/...     images bundled inside the Flutter app (AppImage
    #                  renders these with Image.asset)
    #   data:...       legacy base64 left over from the Firestore era
    if key.startswith(("http://", "https://", "assets/", "data:")):
        return key
    if not settings.s3_bucket_name:
        return ""
    now = time.time()
    cached = _url_cache.get(key)
    if cached is not None and now - cached[1] < _URL_CACHE_SECONDS:
        return cached[0]
    url = _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.s3_bucket_name, "Key": key},
        ExpiresIn=expires_in,
    )
    _url_cache[key] = (url, now)
    return url
