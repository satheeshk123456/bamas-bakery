import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { useNavigate } from 'react-router-dom';
import { auth } from '../firebase.js';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      navigate('/');
    } catch (err) {
      setError('Login failed — check the email and password.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="center-page">
      <form className="card login-card" onSubmit={handleSubmit}>
        <h1>Bamas Burger Admin</h1>
        <p className="muted">Sign in to manage orders and the menu.</p>
        {error && <div className="alert error">{error}</div>}
        <label>Email</label>
        <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        <label>Password</label>
        <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        <button className="btn primary" type="submit" disabled={loading}>
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
        <p className="hint">
          Admin accounts are created in the Firebase console (Authentication tab) —
          see docs/SETUP_GUIDE.md.
        </p>
      </form>
    </div>
  );
}
