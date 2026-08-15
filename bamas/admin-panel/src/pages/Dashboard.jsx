import { useEffect, useState } from 'react';
import { collection, doc, onSnapshot, orderBy, query, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase.js';
import Layout from '../components/Layout.jsx';

const STATUS_LABEL = {
  pending: 'New',
  accepted: 'Accepted',
  rejected: 'Rejected',
  completed: 'Completed',
};

const TABS = ['pending', 'accepted', 'completed', 'rejected'];

export default function Dashboard() {
  const [orders, setOrders] = useState([]);
  const [tab, setTab] = useState('pending');

  useEffect(() => {
    const q = query(collection(db, 'orders'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setOrders(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    });
    return unsub;
  }, []);

  const setStatus = async (orderId, status) => {
    await updateDoc(doc(db, 'orders', orderId), { status, updatedAt: serverTimestamp() });
  };

  const filtered = orders.filter((o) => o.status === tab);

  return (
    <Layout>
      <div className="page-header">
        <h1>Orders</h1>
        <p className="muted">Live — updates instantly as customers order.</p>
      </div>

      <div className="tabs">
        {TABS.map((t) => (
          <button
            key={t}
            className={t === tab ? 'tab active' : 'tab'}
            onClick={() => setTab(t)}
          >
            {STATUS_LABEL[t]} ({orders.filter((o) => o.status === t).length})
          </button>
        ))}
      </div>

      {filtered.length === 0 && <p className="muted">No {STATUS_LABEL[tab].toLowerCase()} orders.</p>}

      <div className="order-grid">
        {filtered.map((order) => (
          <div className="card order-card" key={order.id}>
            <div className="order-card-top">
              <span className="order-id">#{order.id.slice(0, 6).toUpperCase()}</span>
              <span className={`badge ${order.status}`}>{STATUS_LABEL[order.status]}</span>
            </div>
            <div className="order-customer">
              <strong>{order.customerName}</strong>
              <a href={`tel:${order.customerPhone}`}>{order.customerPhone}</a>
            </div>
            <div className="order-address">
              📍 {order.location?.address || 'No address provided'}
              {order.location?.lat && (
                <a
                  className="map-link"
                  target="_blank"
                  rel="noreferrer"
                  href={`https://maps.google.com/?q=${order.location.lat},${order.location.lng}`}
                >
                  Open in Maps
                </a>
              )}
            </div>
            <ul className="order-items">
              {(order.items || []).map((it, i) => (
                <li key={i}>
                  {it.name} × {it.quantity} <span className="muted">₹{it.price * it.quantity}</span>
                </li>
              ))}
            </ul>
            <div className="order-total">Total: ₹{order.totalAmount}</div>
            {order.status === 'accepted' && (
              <div className="order-payment">
                Payment: {order.paymentMethod ? order.paymentMethod.toUpperCase() : 'not chosen yet'}
              </div>
            )}

            <div className="order-actions">
              {order.status === 'pending' && (
                <>
                  <button className="btn primary" onClick={() => setStatus(order.id, 'accepted')}>
                    Accept
                  </button>
                  <button className="btn danger" onClick={() => setStatus(order.id, 'rejected')}>
                    Reject
                  </button>
                </>
              )}
              {order.status === 'accepted' && (
                <button className="btn primary" onClick={() => setStatus(order.id, 'completed')}>
                  Mark Completed
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </Layout>
  );
}
