import { useEffect, useState } from 'react';
import { collection, deleteDoc, doc, onSnapshot, orderBy, query, updateDoc } from 'firebase/firestore';
import { db } from '../firebase.js';
import Layout from '../components/Layout.jsx';

export default function Enquiries() {
  const [enquiries, setEnquiries] = useState([]);
  const [showHandled, setShowHandled] = useState(false);

  useEffect(() => {
    const q = query(collection(db, 'enquiries'), orderBy('createdAt', 'desc'));
    return onSnapshot(q, (snap) =>
      setEnquiries(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    );
  }, []);

  const markHandled = (id, handled) =>
    updateDoc(doc(db, 'enquiries', id), { handled });

  const remove = async (id) => {
    if (!confirm('Delete this enquiry?')) return;
    await deleteDoc(doc(db, 'enquiries', id));
  };

  const visible = enquiries.filter((e) => (showHandled ? true : !e.handled));
  const openCount = enquiries.filter((e) => !e.handled).length;

  return (
    <Layout>
      <div className="page-header">
        <h1>Enquiries</h1>
        <p className="muted">
          Messages customers sent from the app's Enquiry tab. {openCount} unhandled.
        </p>
      </div>

      <label className="inline-check">
        <input
          type="checkbox"
          checked={showHandled}
          onChange={(e) => setShowHandled(e.target.checked)}
        />
        Show handled enquiries too
      </label>

      {visible.length === 0 && <p className="muted">Nothing here right now.</p>}

      <div className="order-grid">
        {visible.map((e) => (
          <div className="card order-card" key={e.id}>
            <div className="order-card-top">
              <strong>{e.name}</strong>
              {e.handled && <span className="badge completed">Handled</span>}
            </div>
            <a href={`tel:${e.phone}`}>{e.phone}</a>
            <p style={{ margin: '8px 0', fontSize: 14, lineHeight: 1.45 }}>{e.message}</p>
            <div className="order-actions">
              {!e.handled ? (
                <button className="btn primary" onClick={() => markHandled(e.id, true)}>
                  Mark handled
                </button>
              ) : (
                <button className="btn ghost small" onClick={() => markHandled(e.id, false)}>
                  Reopen
                </button>
              )}
              <button className="btn ghost small" onClick={() => remove(e.id)}>
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>
    </Layout>
  );
}
