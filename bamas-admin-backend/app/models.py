from typing import Optional

from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class CustomerRegisterRequest(BaseModel):
    """Body for POST /account/register. The backend creates the Firebase
    Auth user itself (Admin SDK) and writes the profile doc -- the app
    never talks to Firebase Auth directly for this."""

    name: str
    phone: str
    email: str
    password: str


class CustomerLoginRequest(BaseModel):
    """Body for POST /account/login. Password is checked server-side via
    Google's Identity Toolkit REST API (the Admin SDK has no way to check
    a password itself)."""

    email: str
    password: str


class ForgotPasswordRequest(BaseModel):
    email: str


class AuthTokenResponse(BaseModel):
    """Returned by /account/register and /account/login. The app signs
    in with this Firebase custom token (FirebaseAuth.signInWithCustomToken)
    to get a normal, auto-refreshing Firebase session -- that one client
    SDK call is unavoidable, it's just adopting a session the backend
    already vouched for, not re-implementing any auth logic."""

    uid: str
    customToken: str


class OrderItem(BaseModel):
    itemId: Optional[str] = None
    name: Optional[str] = None
    price: Optional[float] = None
    quantity: Optional[int] = None


class OrderStatusUpdate(BaseModel):
    status: str  # "accepted" | "rejected" | "completed"


class OrderCreate(BaseModel):
    """Body for the public POST /orders — placing a new order from the
    customer app. No login needed (unlike every other endpoint in this
    backend). This also triggers the "new order" push to the admin app,
    replacing what a Firebase Cloud Function would normally do — done
    this way so the shop doesn't need Firebase's paid Blaze plan."""

    items: list[OrderItem]
    totalAmount: float
    customerName: str
    customerPhone: str
    address: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    fcmToken: Optional[str] = None
    userId: Optional[str] = None  # Firebase Auth uid of the signed-in customer, if any


class MenuItemUpdate(BaseModel):
    isAvailable: Optional[bool] = None
    price: Optional[float] = None
    name: Optional[str] = None
    description: Optional[str] = None


class MenuItemCreate(BaseModel):
    """Body for POST /menu/items — adding a brand-new product from the
    admin app's "+" (add) button. categoryId must match an existing doc id
    from GET /menu/categories."""

    name: str
    description: str = ""
    price: float
    categoryId: str
    imageUrl: Optional[str] = None
    isAvailable: bool = True
    rating: float = 4.5


class ShopSettingsUpdate(BaseModel):
    """Body for PATCH /shop-settings -- every plain-text/boolean field the
    admin's Settings screen can change. Photos (logoUrl, heroImageUrl,
    gpayQrUrl, weekendOfferImageUrl) go through the separate
    POST /shop-settings/image upload instead, since those need a file,
    not JSON."""

    isOpen: Optional[bool] = None
    shopName: Optional[str] = None
    contactPhone: Optional[str] = None
    address: Optional[str] = None
    upiId: Optional[str] = None
    heroHeadline: Optional[str] = None
    heroTagline: Optional[str] = None
    weekendOfferEnabled: Optional[bool] = None
    weekendOfferText: Optional[str] = None


class CategoryCreate(BaseModel):
    """Body for POST /menu/categories -- the admin app's "new category"
    screen. imageUrl is optional at creation time; a photo can also be
    added afterwards via POST /menu/categories/{id}/image."""

    name: str
    imageUrl: Optional[str] = None
    sortOrder: Optional[int] = None


class OfferCreate(BaseModel):
    """Body for POST /offers -- a new home-page promo banner. The image
    is uploaded separately (POST /offers/{id}/image) since this is a
    plain JSON body, not a file upload."""

    title: str
    subtitle: Optional[str] = ""
    isActive: bool = True


class OfferUpdate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    isActive: Optional[bool] = None
    sortOrder: Optional[int] = None


class EnquiryUpdate(BaseModel):
    handled: bool
