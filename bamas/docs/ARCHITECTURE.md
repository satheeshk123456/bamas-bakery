# Architecture

## Stack

- **Customer app**: Flutter → compiles to a single APK, sideloaded (no
  Play Store, no AWS, no domain).
- **Admin website**: React + Vite, deployed to **Firebase Hosting**
  (free `https://<project-id>.web.app` URL, HTTPS included, no domain
  purchase or server to manage).
- **Backend**: Firebase — Firestore (database), Cloud Storage (images),
  Cloud Functions (order notifications), Cloud Messaging (push), Auth
  (admin login only — customers don't log in).

No custom backend server, no Vercel, no MongoDB. See the chat response
this was delivered with for the full reasoning on why Firebase was
chosen over a Vercel + MongoDB Atlas setup for this specific app.

## Data model (Firestore)

```
shopSettings/main
  isOpen: bool
  shopName, logoUrl, gpayQrUrl, upiId, contactPhone: string

categories/{categoryId}
  name: string
  imageUrl: string
  sortOrder: number

menuItems/{itemId}
  name, description: string
  price: number
  imageUrl: string
  categoryId: string        (-> categories/{categoryId})
  isAvailable: bool          <- the "food available or not" toggle
  rating: number
  sortOrder: number

orders/{orderId}
  items: [{ itemId, name, price, quantity }]
  totalAmount: number
  customerName, customerPhone: string
  location: { address: string, lat: number|null, lng: number|null }
  status: "pending" | "accepted" | "rejected" | "completed"
  paymentMethod: "gpay" | "cod" | null
  paymentConfirmedByCustomer: bool
  fcmToken: string|null      <- this customer's device, for push notifications
  createdAt, updatedAt: timestamp
```

## Order flow

1. Customer browses menu (guest — no login), adds items to cart, checks
   out with name, phone, and delivery address (optionally auto-filled via
   GPS + reverse geocoding).
2. Order is created in Firestore with `status: "pending"`.
3. A Cloud Function fires immediately, pushing a notification to the
   admin panel (FCM topic `admin_orders`). Admin panel also shows it live
   via a Firestore real-time listener — no refresh needed either way.
4. Your team calls the customer to confirm, then taps **Accept** or
   **Reject** in the admin panel.
5. If accepted, a Cloud Function pushes a notification to that specific
   customer's phone (matched by the `fcmToken` saved on the order). Their
   app reveals payment options: pay via the shop's GPay QR code, or Cash
   on Delivery.
6. Admin marks the order **Completed** once delivered.

## Why guest checkout, no customer accounts

The client's requirement was "very simple." A phone-OTP login system adds
a whole extra flow (SMS verification, session handling) for a shop doing
~50 orders/day where most customers order rarely. Guest checkout collects
exactly what's needed (name, phone, location) per order and nothing more.
"My Orders" still works without login — the app remembers order IDs
placed from that device locally.

## Security model

Firestore/Storage rules (in `firestore.rules` / `storage.rules`) allow
anyone to *read* the menu and *create* an order, but only a signed-in
admin (verified via an `admins/{uid}` collection) can edit the menu,
shop settings, or change an order's status. A customer's app can only
ever touch their own order's `paymentMethod` field — never totals,
status, or other people's orders.
