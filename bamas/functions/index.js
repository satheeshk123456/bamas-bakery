/**
 * Cloud Functions for Bamas Burger.
 *
 * Two triggers, both intentionally small and easy to read/patch — this is
 * the "microservice"-style piece: fix a bug here, run `firebase deploy
 * --only functions`, and the fix is live immediately for every user with
 * zero app reinstall.
 *
 *  1. onOrderCreated  -> notifies the ADMIN (topic "admin_orders") the
 *     instant a customer places a new order.
 *  2. onOrderUpdated  -> notifies the CUSTOMER's device (their saved FCM
 *     token) when the admin accepts / rejects / completes their order.
 *
 * Requires the Blaze (pay-as-you-go) plan to deploy — at ~50 orders/day
 * this stays comfortably inside the free monthly quota, so the bill is
 * $0 in practice.
 */

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const ADMIN_TOPIC = 'admin_orders';

exports.onOrderCreated = onDocumentCreated('orders/{orderId}', async (event) => {
  const order = event.data?.data();
  if (!order) return;

  const itemCount = Array.isArray(order.items)
    ? order.items.reduce((sum, i) => sum + (i.quantity || 0), 0)
    : 0;

  await getMessaging().send({
    topic: ADMIN_TOPIC,
    notification: {
      title: 'New order received',
      body: `${order.customerName || 'A customer'} • ${itemCount} item(s) • ₹${order.totalAmount ?? ''}`,
    },
    data: {
      type: 'new_order',
      orderId: event.params.orderId,
    },
    android: { priority: 'high' },
  }).catch((err) => {
    // Don't let a notification failure block anything else — just log it.
    console.error('Failed to notify admin topic:', err);
  });
});

exports.onOrderUpdated = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  if (before.status === after.status) return; // only notify on real status changes

  const token = after.fcmToken;
  if (!token) return;

  const messages = {
    accepted: {
      title: 'Order confirmed!',
      body: 'Your order has been accepted. Open the app to choose GPay or Cash on Delivery.',
    },
    rejected: {
      title: 'Order could not be confirmed',
      body: 'Sorry, we could not confirm your order. Please call the shop.',
    },
    completed: {
      title: 'Order completed',
      body: 'Thanks for ordering with us!',
    },
  };

  const notif = messages[after.status];
  if (!notif) return;

  await getMessaging().send({
    token,
    notification: notif,
    data: {
      type: 'order_status',
      orderId: event.params.orderId,
      status: after.status,
    },
    android: { priority: 'high' },
  }).catch((err) => {
    console.error('Failed to notify customer:', err);
  });
});
