import { useEffect, useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { auth, db } from '../firebase.js';

export default function Layout({ children }) {
  const navigate = useNavigate();
  const [newOrders, setNewOrders] = useState(0);
  const [openEnquiries, setOpenEnquiries] = useState(0);

  // Live counters in the sidebar so staff notice work waiting for them.
  useEffect(() => {
    const unsubOrders = onSnapshot(
      query(collection(db, 'orders'), where('status', '==', 'pending')),
      (snap) => setNewOrders(snap.size),
      () => setNewOrders(0),
    );
    const unsubEnq = onSnapshot(
      query(collection(db, 'enquiries'), where('handled', '==', false)),
      (snap) => setOpenEnquiries(snap.size),
      () => setOpenEnquiries(0),
    );
    return () => {
      unsubOrders();
      unsubEnq();
    };
  }, []);

  const logout = async () => {
    await signOut(auth);
    navigate('/login');
  };

  const linkClass = ({ isActive }) => (isActive ? 'nav-link active' : 'nav-link');

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-badge">B</div>
          <div>
            <div className="brand-name">Bama&apos;s Burger Box</div>
            <div className="brand-sub">Admin Panel</div>
          </div>
        </div>
        <nav className="nav">
          <NavLink to="/" end className={linkClass}>
            Orders {newOrders > 0 && <span className="pill">{newOrders}</span>}
          </NavLink>
          <NavLink to="/menu" className={linkClass}>Menu</NavLink>
          <NavLink to="/enquiries" className={linkClass}>
            Enquiries {openEnquiries > 0 && <span className="pill">{openEnquiries}</span>}
          </NavLink>
          <NavLink to="/reviews" className={linkClass}>Reviews</NavLink>
          <NavLink to="/settings" className={linkClass}>Settings</NavLink>
        </nav>
        <button className="btn ghost logout-btn" onClick={logout}>Log out</button>
      </aside>
      <main className="content">{children}</main>
    </div>
  );
}
