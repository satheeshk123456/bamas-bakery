from typing import Optional

from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AdminLoginResponse(TokenResponse):
    """What /auth/login returns now that admins have roles.

    The app needs `role` to decide which screens to show and `branchId` to
    know which branch it is operating as. Neither is trusted by the backend
    -- every request re-reads the account server-side (see
    app/security.py) -- these are purely so the UI can draw itself."""

    role: str = ""
    name: str = ""
    branchId: Optional[str] = None


class CustomerRegisterRequest(BaseModel):
    """Body for POST /account/register. The backend hashes the password
    with bcrypt and stores the customer in MongoDB."""

    name: str
    phone: str
    email: str
    password: str


class CustomerLoginRequest(BaseModel):
    """Body for POST /account/login. The password is checked against the
    bcrypt hash stored in MongoDB."""

    email: str
    password: str


class ForgotPasswordRequest(BaseModel):
    email: str


class AuthTokenResponse(BaseModel):
    """Returned by /account/register and /account/login.

    accessToken is this backend's own JWT (Firebase Authentication has
    been removed). The app stores it and sends it as
    `Authorization: Bearer <accessToken>` on customer requests."""

    uid: str
    accessToken: str
    tokenType: str = "bearer"


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
    # The branch the customer picked. Optional so the already-published
    # customer app (which knows nothing about branches) keeps working: when
    # it is missing the order is filed against the default branch, so no
    # order is ever left unassigned and invisible to every manager.
    branchId: Optional[str] = None


class MenuItemUpdate(BaseModel):
    isAvailable: Optional[bool] = None
    price: Optional[float] = None
    name: Optional[str] = None
    description: Optional[str] = None
    # Moving an item to another branch is an owner-level action; a branch
    # manager sending this is rejected in the router.
    branchId: Optional[str] = None


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
    # Which branch sells this item. Optional in the model so a branch
    # manager can leave it out (the router fills in their own branch), but
    # the router requires one of the two to be present.
    branchId: Optional[str] = None


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


class CategoryUpdate(BaseModel):
    """Body for PATCH /menu/categories/{id} -- rename, reorder, or hide.

    isActive=false hides the category from the customer app without
    touching the items in it, which is what the admin should reach for
    first; DELETE is only for a category that is genuinely empty."""

    name: Optional[str] = None
    sortOrder: Optional[int] = None
    isActive: Optional[bool] = None


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


class EnquiryCreate(BaseModel):
    """Body for the PUBLIC POST /enquiries -- the bamas customer app's
    contact/enquiry form. No login needed. Mirrors the validation the old
    Firestore rule used to do client-side (message under 2000 chars)."""

    message: str
    customerName: Optional[str] = ""
    customerPhone: Optional[str] = ""


class ReviewCreate(BaseModel):
    """Body for the PUBLIC POST /reviews -- a star-rating review from
    the bamas customer app. No login needed. Mirrors the validation the
    old Firestore rule used to do (rating 1-5, comment under 1000 chars)."""

    rating: float
    comment: str = ""
    customerName: Optional[str] = ""


class ProfileUpdate(BaseModel):
    """Body for PATCH /account/me -- a customer editing their own profile."""

    name: str | None = None
    phone: str | None = None


class PaymentUpdate(BaseModel):
    """Body for PATCH /account/orders/{id}/payment -- the customer choosing
    how they'll pay and marking a GPay transfer as sent."""

    paymentMethod: str | None = None
    paymentConfirmedByCustomer: bool | None = None


# ---------------------------------------------------------------------------
# Multi-branch
# ---------------------------------------------------------------------------
class BranchCreate(BaseModel):
    """Body for POST /branches -- super admin only.

    A branch carries its own operational settings: the WhatsApp number its
    orders go to, the UPI id its money lands in, its address, and whether
    it is currently open. Brand-wide things (shop name, logo, hero banner)
    stay in shopSettings and are shared by every branch."""

    name: str
    address: Optional[str] = ""
    contactPhone: Optional[str] = ""
    upiId: Optional[str] = ""
    isOpen: bool = True
    sortOrder: Optional[int] = None


class BranchUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    contactPhone: Optional[str] = None
    upiId: Optional[str] = None
    isOpen: Optional[bool] = None
    sortOrder: Optional[int] = None
    # Super admin only -- checked in the router, not here.
    isActive: Optional[bool] = None


class AdminCreate(BaseModel):
    """Body for POST /admins -- super admin only.

    role is one of super_admin | owner | branch_manager. branchId is
    required for a branch_manager and must be absent for the other two."""

    username: str
    password: str
    name: str = ""
    role: str
    branchId: Optional[str] = None


class AdminUpdate(BaseModel):
    name: Optional[str] = None
    role: Optional[str] = None
    branchId: Optional[str] = None
    isActive: Optional[bool] = None
    # Setting this re-hashes and replaces the account's password. This is
    # the only password reset path -- there is no self-service one.
    password: Optional[str] = None
