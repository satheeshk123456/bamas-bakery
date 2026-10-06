"""Small shared helpers for every router now that MongoDB (not Firestore)
is the datastore. Mirrors the old Firestore doc.id / doc.to_dict()
pattern so the rest of each router reads almost the same as before."""
from datetime import datetime

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import HTTPException


def oid(id_str: str) -> ObjectId:
    """Parses a Mongo _id from a URL path param -- raises a clean 404
    instead of crashing with a 500 if it's not a valid ObjectId (e.g. a
    stale/garbage id from an old bookmark or the wrong collection)."""
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=404, detail="Not found.")


def serialize(doc) -> dict | None:
    """Mongo doc -> JSON-safe dict with a string 'id' field (replacing
    the raw ObjectId), and ISO date strings instead of datetime objects."""
    if doc is None:
        return None
    data = dict(doc)
    _id = data.pop("_id", None)
    data["id"] = str(_id) if _id is not None else None
    for key, value in list(data.items()):
        if isinstance(value, datetime):
            data[key] = value.isoformat()
    return data
