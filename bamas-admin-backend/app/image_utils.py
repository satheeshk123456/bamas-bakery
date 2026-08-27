"""
Shared helper for the base64-in-Firestore image strategy this project
uses everywhere a photo needs to be uploaded (menu items, categories,
offers, shop settings) instead of Firebase Storage. Storage now requires
the paid Blaze plan just to provision a bucket (a Firebase policy change
from September 2024) -- this project deliberately stays on the free
Spark plan, so every uploaded photo is base64-encoded and stored as a
`data:<mime>;base64,...` string directly in the Firestore document that
owns it, and the apps render it straight out of the document they
already fetched (no separate image request, no CDN, no Storage bucket).

Firestore caps a single document at 1 MiB total, and base64 inflates
raw bytes by about a third, so every upload needs a size ceiling that
leaves headroom for the rest of that document's fields:
  - ITEM_IMAGE_MAX_BYTES: collections where each document holds exactly
    ONE image (menuItems/{id}, categories/{id}, offers/{id}).
  - SHOP_IMAGE_MAX_BYTES: shopSettings/main, which can hold up to FOUR
    images at once (logo, hero, GPay QR, weekend offer) in the SAME
    document, so each one gets a much smaller budget.
"""
import base64

from fastapi import HTTPException, UploadFile

ITEM_IMAGE_MAX_BYTES = 700 * 1024   # ~700 KB raw -> ~933 KB base64
SHOP_IMAGE_MAX_BYTES = 200 * 1024   # ~200 KB raw -> ~267 KB base64 (up to 4 share one doc)


def _sniff_mime(raw: bytes) -> str | None:
    """Identifies JPEG/PNG/WEBP from the file's own magic bytes instead of
    trusting the multipart request's Content-Type header. In practice
    phones/Flutter's http package often send a generic
    'application/octet-stream' for a perfectly good photo -- image_picker's
    cache file path doesn't always carry a proper .jpg/.png extension for
    the client's multipart encoder to guess a type from -- so relying on
    that header was rejecting real photos outright. Sniffing the actual
    bytes works no matter what header the client happened to send."""
    if raw[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    return None


async def file_to_data_uri(file: UploadFile, max_bytes: int = ITEM_IMAGE_MAX_BYTES) -> str:
    """Reads an uploaded photo and returns it as a `data:<mime>;base64,...`
    string ready to store straight in a Firestore field.

    Raises HTTP 400 for an unrecognised image type and HTTP 413 if it's
    over `max_bytes` -- both are things the Flutter side surfaces to the
    admin as a plain error message, never a silent failure.
    """
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="The uploaded file was empty.")
    if len(raw) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=(
                f"Image is too large ({len(raw) // 1024} KB). "
                f"Please use a photo under {max_bytes // 1024} KB -- "
                "resize or compress it and try again."
            ),
        )
    mime = _sniff_mime(raw)
    if mime is None:
        raise HTTPException(
            status_code=400,
            detail="Unsupported image type. Please upload a JPEG, PNG, or WEBP photo.",
        )
    encoded = base64.b64encode(raw).decode("ascii")
    return f"data:{mime};base64,{encoded}"
