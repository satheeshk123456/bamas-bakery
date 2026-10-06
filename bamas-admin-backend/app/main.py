from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import (
    account,
    admins,
    auth,
    backup,
    branches,
    feedback,
    menu,
    offers,
    orders,
    shop,
)

app = FastAPI(
    title="Bamas Admin API",
    description=(
        "Backend for the Bamas customer + admin Flutter apps. Data lives "
        "in MongoDB (food_order_db) and images in S3, both on AWS. "
        "Firebase is used only for FCM push notifications -- admin and "
        "customer identity are both this backend's own JWTs."
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
app.include_router(admins.router)
app.include_router(branches.router)
app.include_router(account.router)
app.include_router(orders.router)
app.include_router(orders.public_router)
app.include_router(menu.router)
app.include_router(offers.router)
app.include_router(feedback.router)
app.include_router(feedback.public_router)
app.include_router(shop.router)
app.include_router(backup.router)


@app.get("/health")
def health():
    return {"status": "ok"}
