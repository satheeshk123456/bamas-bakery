from typing import Optional

from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class OrderItem(BaseModel):
    itemId: Optional[str] = None
    name: Optional[str] = None
    price: Optional[float] = None
    quantity: Optional[int] = None


class OrderStatusUpdate(BaseModel):
    status: str  # "accepted" | "rejected" | "completed"


class MenuItemUpdate(BaseModel):
    isAvailable: Optional[bool] = None
    price: Optional[float] = None
    name: Optional[str] = None
    description: Optional[str] = None


class ShopSettingsUpdate(BaseModel):
    isOpen: Optional[bool] = None
