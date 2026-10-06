"""
Seed the database with a starter menu.

    venv/bin/python deploy/seed.py               # dry run - shows what it would create
    venv/bin/python deploy/seed.py --write       # create, skipping anything already there
    venv/bin/python deploy/seed.py --write --reset   # DELETE menu data first, then create

Safe by default:
  * dry run unless --write
  * without --reset it only ADDS what is missing, matching on name, so
    running it twice will not duplicate your menu
  * --reset only ever clears categories / menuItems / offers / shopSettings.
    It NEVER touches orders, users, reviews or enquiries.

Images: seeded items use the Flutter app's bundled assets (assets/images/...)
and public stock photo URLs. The backend passes both through untouched, so
they display without anything needing to exist in S3.
"""
import argparse
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId

from app.mongo_client import get_db

SEEDABLE = ["categories", "menuItems", "offers", "shopSettings"]
PROTECTED = ["orders", "users", "reviews", "enquiries"]

SHOP = {
    "shopName": "Bama's Burger Box",
    "isOpen": True,
    "phone": "",
    "address": "",
    "upiId": "",
    "logoUrl": "",
    "heroImageUrl": "",
    "gpayQrUrl": "",
    "weekendOfferImageUrl": "",
}

CATEGORIES = [
    {"name": "Burgers", "imageUrl": "assets/images/cat_burgers.png", "sortOrder": 1},
    {"name": "Sides", "imageUrl": "assets/images/cat_sides.png", "sortOrder": 2},
    {"name": "Drinks", "imageUrl": "assets/images/cat_drinks.png", "sortOrder": 3},
    {"name": "Combos", "imageUrl": "assets/images/cat_combos.png", "sortOrder": 4},
]

# (category name, item)
ITEMS = [
    ("Burgers", {"name": "Classic Veg Burger", "price": 90, "rating": 4.5, "sortOrder": 1,
                 "description": "Crispy veg patty, cheddar, lettuce, house sauce.",
                 "imageUrl": "https://images.pexels.com/photos/3607284/pexels-photo-3607284.jpeg"}),
    ("Burgers", {"name": "Spicy Chicken Burger", "price": 130, "rating": 4.7, "sortOrder": 2,
                 "description": "Crispy chicken fillet, spicy mayo, pickles.",
                 "imageUrl": "https://images.pexels.com/photos/11354334/pexels-photo-11354334.jpeg"}),
    ("Burgers", {"name": "Double Cheese Burger", "price": 180, "rating": 4.8, "sortOrder": 3,
                 "description": "Two patties, double cheddar, smoky sauce.",
                 "imageUrl": "https://images.pexels.com/photos/12325120/pexels-photo-12325120.jpeg"}),
    ("Burgers", {"name": "Paneer Tikka Burger", "price": 120, "rating": 4.4, "sortOrder": 4,
                 "description": "Grilled paneer, mint mayo, onions.",
                 "imageUrl": "https://images.pexels.com/photos/19247575/pexels-photo-19247575.jpeg"}),
    ("Sides", {"name": "Peri Peri Fries", "price": 80, "rating": 4.4, "sortOrder": 1,
               "description": "Crispy fries tossed in peri peri seasoning.",
               "imageUrl": "https://images.pexels.com/photos/4109234/pexels-photo-4109234.jpeg"}),
    ("Sides", {"name": "Cheesy Nachos", "price": 95, "rating": 4.3, "sortOrder": 2,
               "description": "Corn nachos with molten cheese dip.",
               "imageUrl": "https://images.pexels.com/photos/5211212/pexels-photo-5211212.jpeg"}),
    ("Sides", {"name": "Salted Fries", "price": 60, "rating": 4.2, "sortOrder": 3,
               "description": "Golden, hot and lightly salted.",
               "imageUrl": "https://images.pexels.com/photos/4109234/pexels-photo-4109234.jpeg"}),
    ("Drinks", {"name": "Chilled Cola", "price": 40, "rating": 4.6, "sortOrder": 1,
                "description": "Ice cold 300ml bottle.",
                "imageUrl": "https://images.pexels.com/photos/8879617/pexels-photo-8879617.jpeg"}),
    ("Drinks", {"name": "Chocolate Shake", "price": 110, "rating": 4.7, "sortOrder": 2,
                "description": "Thick shake with chocolate syrup.",
                "imageUrl": "https://images.pexels.com/photos/3727250/pexels-photo-3727250.jpeg"}),
    ("Combos", {"name": "Burger + Fries + Cola", "price": 210, "rating": 4.9, "sortOrder": 1,
                "description": "The full meal, best value.",
                "imageUrl": "https://images.pexels.com/photos/19247564/pexels-photo-19247564.jpeg"}),
    ("Combos", {"name": "Family Box (4 Burgers)", "price": 620, "rating": 4.8, "sortOrder": 2,
                "description": "Four burgers, two large fries, four colas.",
                "imageUrl": "https://images.pexels.com/photos/19247564/pexels-photo-19247564.jpeg"}),
]

OFFERS = [
    {"title": "Weekend Combo Deal", "subtitle": "Save on family boxes",
     "imageUrl": "", "isActive": True, "sortOrder": 1},
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="actually write (default: dry run)")
    ap.add_argument("--reset", action="store_true",
                    help="delete existing menu data first (never touches orders/users)")
    args = ap.parse_args()
    dry = not args.write

    db = get_db()
    print("=" * 70)
    print("  seed menu   %s" % ("[DRY RUN - nothing written]" if dry else "[WRITING]"))
    print("=" * 70)

    for c in PROTECTED:
        print("  %-14s %d documents  (never modified by this script)" % (c, db[c].count_documents({})))
    print()

    if args.reset:
        if dry:
            print("  --reset would DELETE: " +
                  ", ".join("%s=%d" % (c, db[c].count_documents({})) for c in SEEDABLE))
        else:
            for c in SEEDABLE:
                n = db[c].count_documents({})
                db[c].delete_many({})
                print("  cleared %-14s (%d removed)" % (c, n))
        print()

    now = datetime.now(timezone.utc)
    created = {"categories": 0, "menuItems": 0, "offers": 0, "shopSettings": 0}
    skipped = 0

    # shop settings
    if db.shopSettings.find_one({"_id": "main"}) is None:
        if not dry:
            db.shopSettings.insert_one({"_id": "main", **SHOP})
        created["shopSettings"] += 1
    else:
        skipped += 1

    # categories (matched by name so re-running does not duplicate)
    cat_ids = {}
    for c in CATEGORIES:
        found = db.categories.find_one({"name": c["name"]})
        if found:
            cat_ids[c["name"]] = str(found["_id"])
            skipped += 1
            continue
        _id = ObjectId()
        cat_ids[c["name"]] = str(_id)
        if not dry:
            db.categories.insert_one({"_id": _id, **c})
        created["categories"] += 1

    # menu items
    for cat_name, item in ITEMS:
        if db.menuItems.find_one({"name": item["name"]}):
            skipped += 1
            continue
        doc = dict(item)
        doc["categoryId"] = cat_ids.get(cat_name, "")
        doc.setdefault("isAvailable", True)
        doc.setdefault("description", "")
        if not dry:
            db.menuItems.insert_one({"_id": ObjectId(), **doc})
        created["menuItems"] += 1

    # offers
    for o in OFFERS:
        if db.offers.find_one({"title": o["title"]}):
            skipped += 1
            continue
        if not dry:
            db.offers.insert_one({"_id": ObjectId(), **o})
        created["offers"] += 1

    print("  would create:" if dry else "  created:")
    for k, v in created.items():
        print("     %-14s %d" % (k, v))
    print("     %-14s %d (already present, left alone)" % ("skipped", skipped))
    print("=" * 70)
    if dry:
        print("  DRY RUN - nothing was written. Re-run with --write to apply.")
    else:
        print("  DONE. Menu now: categories=%d, menuItems=%d, offers=%d" % (
            db.categories.count_documents({}), db.menuItems.count_documents({}),
            db.offers.count_documents({})))
    print("=" * 70)


if __name__ == "__main__":
    main()
