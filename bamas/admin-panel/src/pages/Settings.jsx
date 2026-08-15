import { useEffect, useState } from 'react';
import { doc, onSnapshot, setDoc } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../firebase.js';
import Layout from '../components/Layout.jsx';

const DOC_REF = () => doc(db, 'shopSettings', 'main');

export default function Settings() {
  const [settings, setSettings] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const unsub = onSnapshot(DOC_REF(), (snap) => {
      setSettings(
        snap.data() || {
          isOpen: true,
          shopName: 'Bamas Burger',
          logoUrl: '',
          gpayQrUrl: '',
          upiId: '',
          contactPhone: '',
        },
      );
    });
    return unsub;
  }, []);

  const save = async (patch) => {
    setSaving(true);
    try {
      await setDoc(DOC_REF(), { ...settings, ...patch }, { merge: true });
    } finally {
      setSaving(false);
    }
  };

  const uploadFile = async (file, name) => {
    const path = `public/shop/${name}_${Date.now()}_${file.name}`;
    const storageRef = ref(storage, path);
    await uploadBytes(storageRef, file);
    return getDownloadURL(storageRef);
  };

  if (!settings) return <Layout><p className="muted">Loading…</p></Layout>;

  return (
    <Layout>
      <div className="page-header">
        <h1>Settings</h1>
        <p className="muted">Shop status, branding and GPay payment details.</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2>Shop status</h2>
        <label className="switch large">
          <input
            type="checkbox"
            checked={settings.isOpen}
            onChange={(e) => save({ isOpen: e.target.checked })}
          />
          <span className="slider" />
        </label>
        <span style={{ marginLeft: 12, fontWeight: 600 }}>
          {settings.isOpen ? 'Open — accepting orders' : 'Closed — ordering paused'}
        </span>
        <p className="muted">Toggling this instantly shows/hides ordering in the customer app — no app update needed.</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2>Shop details</h2>
        <label>Shop name</label>
        <input
          defaultValue={settings.shopName}
          onBlur={(e) => save({ shopName: e.target.value })}
        />
        <label>Contact phone (shown to customers)</label>
        <input
          defaultValue={settings.contactPhone}
          onBlur={(e) => save({ contactPhone: e.target.value })}
        />
        <label>Logo</label>
        <div className="upload-row">
          {settings.logoUrl && <img src={settings.logoUrl} alt="logo" className="preview-img" />}
          <input
            type="file"
            accept="image/*"
            onChange={async (e) => {
              const file = e.target.files[0];
              if (!file) return;
              const url = await uploadFile(file, 'logo');
              save({ logoUrl: url });
            }}
          />
        </div>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2>Home screen banner</h2>
        <p className="muted">
          Controls the big banner at the top of the customer app. Changes appear instantly — no app update needed.
        </p>
        <label>Headline</label>
        <input
          placeholder="Your Burger Cravings, Sorted"
          defaultValue={settings.heroHeadline || ''}
          onBlur={(e) => save({ heroHeadline: e.target.value })}
        />
        <label>Tagline</label>
        <input
          placeholder="Taste the Love, Feel the Quality"
          defaultValue={settings.heroTagline || ''}
          onBlur={(e) => save({ heroTagline: e.target.value })}
        />
        <label>Shop address (shown on the Enquiry tab)</label>
        <input
          defaultValue={settings.address || ''}
          onBlur={(e) => save({ address: e.target.value })}
        />
        <label>Banner photo (a photo of the shop or the food)</label>
        <div className="upload-row">
          {settings.heroImageUrl && (
            <img src={settings.heroImageUrl} alt="banner" className="preview-img wide" />
          )}
          <input
            type="file"
            accept="image/*"
            onChange={async (e) => {
              const file = e.target.files[0];
              if (!file) return;
              const url = await uploadFile(file, 'hero');
              save({ heroImageUrl: url });
            }}
          />
        </div>
      </div>

      <div className="card">
        <h2>GPay payment</h2>
        <label>UPI ID</label>
        <input
          placeholder="yourshop@upi"
          defaultValue={settings.upiId}
          onBlur={(e) => save({ upiId: e.target.value })}
        />
        <label>GPay QR code image</label>
        <div className="upload-row">
          {settings.gpayQrUrl && <img src={settings.gpayQrUrl} alt="qr" className="preview-img qr" />}
          <input
            type="file"
            accept="image/*"
            onChange={async (e) => {
              const file = e.target.files[0];
              if (!file) return;
              const url = await uploadFile(file, 'gpay_qr');
              save({ gpayQrUrl: url });
            }}
          />
        </div>
        <p className="muted">
          This QR code is shown to the customer only after you accept their order and they choose "Pay via GPay".
        </p>
      </div>
      {saving && <p className="muted">Saving…</p>}
    </Layout>
  );
}
