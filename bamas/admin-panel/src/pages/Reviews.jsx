import { useEffect, useState } from 'react';
import { collection, deleteDoc, doc, onSnapshot, orderBy, query } from 'firebase/firestore';
import { db } from '../firebase.js';
import Layout from '../components/Layout.jsx';

export default function Reviews() {
  const [reviews, setReviews] = useState([]);

  useEffect(() => {
    const q = query(collection(db, 'reviews'), orderBy('createdAt', 'desc'));
    return onSnapshot(q, (snap) =>
      setReviews(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    );
  }, []);

  const remove = async (id) => {
    if (!confirm('Delete this review? This cannot be undone.')) return;
    await deleteDoc(doc(db, 'reviews', id));
  };

  const avg = reviews.length
    ? (reviews.reduce((s, r) => s + (r.rating || 0), 0) / reviews.length).toFixed(1)
    : '—';

  return (
    <Layout>
      <div className="page-header">
        <h1>Reviews</h1>
        <p className="muted">
          Average rating {avg} from {reviews.length} review{reviews.length === 1 ? '' : 's'}.
          Customers post these from the app — delete any that are spam or abusive.
        </p>
      </div>

      {reviews.length === 0 && <p className="muted">No reviews yet.</p>}

      <div className="order-grid">
        {reviews.map((r) => (
          <div className="card order-card" key={r.id}>
            <div className="order-card-top">
              <strong>{r.customerName}</strong>
              <span className="stars">{'★'.repeat(Math.round(r.rating || 0)).padEnd(5, '☆')}</span>
            </div>
            {r.comment && (
              <p style={{ margin: '6px 0', fontSize: 14, lineHeight: 1.45 }}>{r.comment}</p>
            )}
            <div className="order-actions">
              <button className="btn ghost small" onClick={() => remove(r.id)}>Delete</button>
            </div>
          </div>
        ))}
      </div>
    </Layout>
  );
}
