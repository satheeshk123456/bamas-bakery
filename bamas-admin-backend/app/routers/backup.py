import io
import json
from datetime import datetime, timezone

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse

from ..config import settings
from ..mongo_client import get_db
from ..security import get_current_admin

router = APIRouter(prefix="/backup", tags=["backup"])

# branches and admins come first so a restored spreadsheet rebuilds them
# before the menu items and orders that carry their ids.
BACKUP_COLLECTIONS = [
    "branches",
    "admins",
    "menuItems",
    "categories",
    "offers",
    "shopSettings",
    "orders",
    "users",
    "reviews",
    "enquiries",
]


def _json_safe(value):
    """Mongo hands back ObjectId and datetime values that json.dumps
    can't serialize directly -- convert them recursively. Note: image
    fields are stored as plain S3 KEYS (not presigned URLs) in Mongo, so
    they come through here as-is, which is what we want for a backup --
    a presigned URL would just expire."""
    if isinstance(value, ObjectId):
        return str(value)
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    return value


def _build_backup_payload() -> dict:
    db = get_db()
    collections = {}
    for name in BACKUP_COLLECTIONS:
        docs = list(db[name].find())
        collections[name] = {str(d["_id"]): _json_safe({k: v for k, v in d.items() if k != "_id"}) for d in docs}
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "shop": "Bama's Burger Box",
        "collections": collections,
    }


def _as_download(payload: dict) -> StreamingResponse:
    body = json.dumps(payload, indent=2, ensure_ascii=False)
    filename = f"bamas-backup-{datetime.now(timezone.utc).strftime('%Y-%m-%d')}.json"
    return StreamingResponse(
        iter([body]),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/full")
def download_backup_admin(admin: str = Depends(get_current_admin)):
    """Manual full-data backup -- the "Download full backup now" button
    in the admin app. Requires a normal logged-in admin session."""
    return _as_download(_build_backup_payload())


def _verify_backup_key(x_backup_key: str | None = Header(None)):
    """A SEPARATE, narrower credential from the real admin login -- used
    only by the weekly automated backup job. If this key ever leaked it
    only grants read access to a data export -- no login, no writes."""
    if not settings.backup_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Server is missing BACKUP_SECRET_KEY.",
        )
    if not x_backup_key or x_backup_key != settings.backup_secret_key:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid backup key.")


@router.get("/full/scheduled", dependencies=[Depends(_verify_backup_key)])
def download_backup_scheduled():
    """Same export as /backup/full, but authenticated with the
    long-lived X-Backup-Key header -- the weekly automated backup task
    calls this one, with nobody logged in."""
    return _as_download(_build_backup_payload())


# ---------------------------------------------------------------------------
# Excel backup + restore
#
# The JSON export above is exact but unreadable to a person. This writes the
# same data as a spreadsheet the shop owner can open, and can read it back if
# the database is ever lost.
#
# The important part is _id. Orders point at a customer through `userId`,
# and menu items point at a category through `categoryId`. If a restore
# invented new ids, every one of those links would break and customers would
# stop seeing their old orders. So each row carries its original _id and the
# restore writes that same id back.
#
# A hidden "_meta" sheet records the type of every column (json / date /
# number / bool / text) and whether each collection's _id is a Mongo
# ObjectId or a plain string, so reading the file back is exact rather than
# guesswork.
# ---------------------------------------------------------------------------

META_SHEET = "_meta"
# shopSettings uses the literal id "main"; users use the customer's uid.
STRING_ID_COLLECTIONS = {"shopSettings", "users"}


def _cell_value(value):
    """One Mongo value -> (cell text, type tag)."""
    if value is None:
        return "", "null"
    if isinstance(value, ObjectId):
        return str(value), "text"
    if isinstance(value, datetime):
        return value.isoformat(), "date"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE", "bool"
    if isinstance(value, (int, float)):
        return value, "number"
    if isinstance(value, (dict, list)):
        return json.dumps(_json_safe(value), ensure_ascii=False), "json"
    return str(value), "text"


def _decode_cell(raw, kind):
    """Cell text -> the Mongo value it came from."""
    if raw is None or raw == "":
        return None
    if kind == "json":
        try:
            return json.loads(raw) if isinstance(raw, str) else raw
        except (ValueError, TypeError):
            return raw
    if kind == "date":
        if isinstance(raw, datetime):
            return raw if raw.tzinfo else raw.replace(tzinfo=timezone.utc)
        try:
            parsed = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return raw
    if kind == "bool":
        return str(raw).strip().upper() in ("TRUE", "1", "YES")
    if kind == "number":
        try:
            f = float(raw)
            return int(f) if f.is_integer() and "." not in str(raw) else f
        except (ValueError, TypeError):
            return raw
    return raw


def _build_workbook() -> bytes:
    from openpyxl import Workbook

    db = get_db()
    wb = Workbook()
    wb.remove(wb.active)
    meta_rows = []

    for name in BACKUP_COLLECTIONS:
        docs = list(db[name].find())
        ws = wb.create_sheet(title=name[:31])

        # every field seen anywhere in the collection, _id first
        fields, types = ["_id"], {"_id": "text"}
        for d in docs:
            for k, v in d.items():
                if k == "_id":
                    continue
                _, kind = _cell_value(v)
                if k not in types or types[k] == "null":
                    types[k] = kind
                if k not in fields:
                    fields.append(k)

        ws.append(fields)
        for d in docs:
            row = []
            for f in fields:
                text, _ = _cell_value(d.get(f))
                row.append(text)
            ws.append(row)

        id_kind = "str" if name in STRING_ID_COLLECTIONS else "oid"
        for f in fields:
            meta_rows.append([name, f, types.get(f, "text"), id_kind])

    meta = wb.create_sheet(title=META_SHEET)
    meta.append(["collection", "field", "type", "id_kind"])
    for r in meta_rows:
        meta.append(r)
    meta.sheet_state = "hidden"

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _excel_download() -> StreamingResponse:
    data = _build_workbook()
    filename = "bamas-backup-%s.xlsx" % datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return StreamingResponse(
        iter([data]),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": 'attachment; filename="%s"' % filename},
    )


@router.get("/excel")
def download_excel_admin(admin: str = Depends(get_current_admin)):
    """Full backup as a spreadsheet - the admin app's download button."""
    return _excel_download()


@router.get("/excel/scheduled", dependencies=[Depends(_verify_backup_key)])
def download_excel_scheduled():
    """Same spreadsheet, for the automated weekly job."""
    return _excel_download()


@router.post("/restore")
async def restore_from_excel(
    file: UploadFile = File(...),
    confirm: str = "",
    admin: str = Depends(get_current_admin),
):
    """Rebuild the database from a spreadsheet produced by /backup/excel.

    This REPLACES the collections it finds in the file, so it is guarded by
    an explicit confirm string - a mistyped tap must not wipe a live shop.
    Original _id values are restored exactly, which is what keeps each
    customer's old orders attached to them.
    """
    if confirm != "REPLACE-ALL-DATA":
        raise HTTPException(
            status_code=400,
            detail=("Restore not confirmed. This replaces existing data. "
                    "Send confirm=REPLACE-ALL-DATA to proceed."),
        )

    from openpyxl import load_workbook

    raw = await file.read()
    try:
        wb = load_workbook(io.BytesIO(raw), data_only=True)
    except Exception as e:
        raise HTTPException(status_code=400, detail="Not a readable .xlsx file (%s)." % e)

    if META_SHEET not in wb.sheetnames:
        raise HTTPException(
            status_code=400,
            detail="This file wasn't produced by the backup export (no _meta sheet).",
        )

    # column types, from the sheet the export wrote
    types: dict[tuple[str, str], str] = {}
    id_kinds: dict[str, str] = {}
    meta = wb[META_SHEET]
    for row in meta.iter_rows(min_row=2, values_only=True):
        if not row or not row[0]:
            continue
        coll, field, kind, id_kind = (list(row) + [None] * 4)[:4]
        types[(coll, field)] = kind or "text"
        if id_kind:
            id_kinds[coll] = id_kind

    db = get_db()
    parsed: dict[str, list] = {}
    problems: list[str] = []

    # Parse EVERYTHING before writing anything: a file that is broken
    # halfway through must not leave the database half-replaced.
    for name in BACKUP_COLLECTIONS:
        if name not in wb.sheetnames:
            continue
        ws = wb[name]
        rows = list(ws.iter_rows(values_only=True))
        if not rows:
            parsed[name] = []
            continue
        header = [str(h) if h is not None else "" for h in rows[0]]
        if "_id" not in header:
            problems.append("%s: no _id column" % name)
            continue

        docs = []
        for row in rows[1:]:
            if row is None or all(c is None or c == "" for c in row):
                continue
            doc = {}
            for col, value in zip(header, row):
                if not col:
                    continue
                if col == "_id":
                    continue
                decoded = _decode_cell(value, types.get((name, col), "text"))
                if decoded is not None:
                    doc[col] = decoded

            raw_id = dict(zip(header, row)).get("_id")
            if raw_id is None or str(raw_id).strip() == "":
                problems.append("%s: a row has no _id, skipped" % name)
                continue
            raw_id = str(raw_id).strip()
            if id_kinds.get(name, "oid") == "oid":
                try:
                    doc["_id"] = ObjectId(raw_id)
                except (InvalidId, TypeError):
                    problems.append("%s: bad id %r, skipped" % (name, raw_id))
                    continue
            else:
                doc["_id"] = raw_id
            docs.append(doc)
        parsed[name] = docs

    if problems and not parsed:
        raise HTTPException(status_code=400, detail="; ".join(problems[:5]))

    # Write: replace each collection present in the file.
    report = {}
    for name, docs in parsed.items():
        db[name].delete_many({})
        if docs:
            db[name].insert_many(docs)
        report[name] = len(docs)

    return {
        "restored": True,
        "collections": report,
        "totalDocuments": sum(report.values()),
        "warnings": problems[:20],
    }
