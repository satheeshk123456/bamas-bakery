"""
Pushes a starter food list (categories + menu items) into Firestore, so
the bamas app isn't empty on first run.

Uses the SAME Firebase Admin SDK connection as the rest of this backend
(see app/firebase_client.py) — so it needs the same setup already used
for local dev: a serviceAccountKey.json file next to this script
(FIREBASE_SERVICE_ACCOUNT_PATH in .env points at it by default).

Safe to run more than once: categories and menu items use fixed, readable
document IDs (e.g. "burgers", "classic-veg-burger"), so re-running this
just overwrites the same documents instead of creating duplicates.

Usage:
    cd bamas-admin-backend
    python seed.py
"""
from app.firebase_client import get_db

# Images point at the app's own bundled assets (assets/images/...) — the
# app already knows how to show those (see lib/widgets/app_image.dart),
# no Firebase Storage upload needed just to get a menu on screen. Swap
# in real photos any time from the admin panel's Add/Edit Item screen —
# that uploads to Storage and the app picks up the new URL automatically.

CATEGORIES = [
    {"id": "burgers", "name": "Burgers", "imageUrl": "assets/images/cat_burgers.png", "sortOrder": 1},
    {"id": "sides", "name": "Sides", "imageUrl": "assets/images/cat_sides.png", "sortOrder": 2},
    {"id": "drinks", "name": "Drinks", "imageUrl": "assets/images/cat_drinks.png", "sortOrder": 3},
    {"id": "combos", "name": "Combos", "imageUrl": "assets/images/cat_combos.png", "sortOrder": 4},
]

# Shop-wide settings (hero banner, logo, contact info) shown on the
# customer app's home screen. Like the categories/items above, the hero
# and logo images point at bundled assets for now — no Firebase Storage
# needed. Swap these for real photo URLs any time from the admin panel's
# Settings screen once that's wired up to real image hosting.
SHOP_SETTINGS = {
    "isOpen": True,
    "shopName": "Bama's Burger Box",
    "logoUrl": "https://images.pexels.com/photos/19247562/pexels-photo-19247562.jpeg",
    "heroImageUrl": "https://images.pexels.com/photos/5488052/pexels-photo-5488052.jpeg",
    "heroHeadline": "Your Burger Cravings, Sorted",
    "heroTagline": "Taste the Love, Feel the Quality",
    "address": "",
    "contactPhone": "+917708704534",
    "gpayQrUrl": "assets/images/gpay_qr_placeholder.png",
    "upiId": "",
    "weekendOfferEnabled": False,
    "weekendOfferText": "",
    "weekendOfferImageUrl": "",
}

MENU_ITEMS = [
    {"id": "classic-veg-burger", "name": "Classic Veg Burger",
     "description": "Crispy veg patty, cheddar, lettuce, house sauce.",
     "price": 90, "imageUrl": "https://images.pexels.com/photos/3607284/pexels-photo-3607284.jpeg",
     "categoryId": "burgers", "isAvailable": True, "rating": 4.5, "sortOrder": 1},
    {"id": "spicy-chicken-burger", "name": "Spicy Chicken Burger",
     "description": "Crispy chicken fillet, spicy mayo, pickles.",
     "price": 130, "imageUrl": "https://images.pexels.com/photos/11354334/pexels-photo-11354334.jpeg",
     "categoryId": "burgers", "isAvailable": True, "rating": 4.7, "sortOrder": 2},
    {"id": "double-cheese-burger", "name": "Double Cheese Burger",
     "description": "Two patties, double cheddar, smoky sauce.",
     "price": 180, "imageUrl": "https://images.pexels.com/photos/12325120/pexels-photo-12325120.jpeg",
     "categoryId": "burgers", "isAvailable": True, "rating": 4.8, "sortOrder": 3},
    {"id": "paneer-tikka-burger", "name": "Paneer Tikka Burger",
     "description": "Grilled paneer, mint mayo, onions.",
     "price": 120, "imageUrl": "https://images.pexels.com/photos/19247575/pexels-photo-19247575.jpeg",
     "categoryId": "burgers", "isAvailable": True, "rating": 4.4, "sortOrder": 4},
    {"id": "peri-peri-fries", "name": "Peri Peri Fries",
     "description": "Crispy fries tossed in peri peri seasoning.",
     "price": 80, "imageUrl": "https://images.pexels.com/photos/4109234/pexels-photo-4109234.jpeg",
     "categoryId": "sides", "isAvailable": True, "rating": 4.4, "sortOrder": 1},
    {"id": "cheesy-nachos", "name": "Cheesy Nachos",
     "description": "Corn nachos with molten cheese dip.",
     "price": 95, "imageUrl": "https://images.pexels.com/photos/5211212/pexels-photo-5211212.jpeg",
     "categoryId": "sides", "isAvailable": True, "rating": 4.3, "sortOrder": 2},
    {"id": "salted-fries", "name": "Salted Fries",
     "description": "Golden, hot and lightly salted.",
     "price": 60, "imageUrl": "https://images.pexels.com/photos/4109234/pexels-photo-4109234.jpeg",
     "categoryId": "sides", "isAvailable": True, "rating": 4.2, "sortOrder": 3},
    {"id": "chilled-cola", "name": "Chilled Cola",
     "description": "Ice cold 300ml bottle.",
     "price": 40, "imageUrl": "https://images.pexels.com/photos/8879617/pexels-photo-8879617.jpeg",
     "categoryId": "drinks", "isAvailable": True, "rating": 4.6, "sortOrder": 1},
    {"id": "chocolate-shake", "name": "Chocolate Shake",
     "description": "Thick shake with chocolate syrup.",
     "price": 110, "imageUrl": "https://images.pexels.com/photos/3727250/pexels-photo-3727250.jpeg",
     "categoryId": "drinks", "isAvailable": True, "rating": 4.7, "sortOrder": 2},
    {"id": "burger-fries-cola-combo", "name": "Burger + Fries + Cola",
     "description": "The full meal, best value.",
     "price": 210, "imageUrl": "https://images.pexels.com/photos/19247564/pexels-photo-19247564.jpeg",
     "categoryId": "combos", "isAvailable": True, "rating": 4.9, "sortOrder": 1},
    {"id": "family-box-4-burgers", "name": "Family Box (4 Burgers)",
     "description": "Four burgers, two large fries, four colas.",
     "price": 620, "imageUrl": "https://images.pexels.com/photos/19247564/pexels-photo-19247564.jpeg",
     "categoryId": "combos", "isAvailable": True, "rating": 4.8, "sortOrder": 2},
]


def main():
    db = get_db()

    db.collection("shopSettings").document("main").set(SHOP_SETTINGS, merge=True)
    print("shop settings: main")

    for cat in CATEGORIES:
        doc_id = cat["id"]
        data = {k: v for k, v in cat.items() if k != "id"}
        db.collection("categories").document(doc_id).set(data)
        print(f"category:  {doc_id}")

    for item in MENU_ITEMS:
        doc_id = item["id"]
        data = {k: v for k, v in item.items() if k != "id"}
        db.collection("menuItems").document(doc_id).set(data)
        print(f"menu item: {doc_id}")

    print(f"\nDone — {len(CATEGORIES)} categories, {len(MENU_ITEMS)} menu items pushed to Firestore.")


if __name__ == "__main__":
    main()
