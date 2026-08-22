from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import auth, menu, orders, shop

app = FastAPI(
    title="Bamas Admin API",
    description=(
        "Backend for the Bamas Admin Flutter app. Talks to the SAME "
        "Firebase project the customer app already uses (see "
        "bamas/docs/ARCHITECTURE.md) via the Firebase Admin SDK — this is "
        "not a separate database, it's an admin-only REST layer in front "
        "of the existing Firestore."
    ),
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(orders.router)
app.include_router(menu.router)
app.include_router(shop.router)


@app.get("/health")
def health():
    return {"status": "ok"}
    const admin = require("firebase-admin");

// Neenga backend folder-la pota antha json file-oda path
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // Unga database URL-a inga podanum
  databaseURL: "https://console.firebase.google.com/u/0/project/bamas-2725a/firestore/databases/-default-/security/rules"
});

const db = admin.database();
console.log("Firebase Backend kooda connect aagiduchu!");
