import { useEffect, useState } from 'react';
import {
  addDoc, collection, deleteDoc, doc, onSnapshot, orderBy, query, updateDoc,
} from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../firebase.js';
import Layout from '../components/Layout.jsx';

const EMPTY_FORM = { name: '', description: '', price: '', rating: '4.5', categoryId: '', file: null };

export default function Menu() {
  const [categories, setCategories] = useState([]);
  const [items, setItems] = useState([]);
  const [newCategory, setNewCategory] = useState('');
  const [itemForm, setItemForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState(null);
  const [editingImageUrl, setEditingImageUrl] = useState('');
  const [saving, setSaving] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);

  useEffect(() => {
    const unsubCats = onSnapshot(query(collection(db, 'categories'), orderBy('sortOrder')), (snap) =>
      setCategories(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    );
    const unsubItems = onSnapshot(collection(db, 'menuItems'), (snap) =>
      setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    );
    return () => {
      unsubCats();
      unsubItems();
    };
  }, []);

  const addCategory = async (e) => {
    e.preventDefault();
    if (!newCategory.trim()) return;
    await addDoc(collection(db, 'categories'), {
      name: newCategory.trim(),
      imageUrl: '',
      sortOrder: categories.length + 1,
    });
    setNewCategory('');
  };

  const deleteCategory = async (id) => {
    if (!confirm('Delete this category? Items in it will remain but be uncategorized.')) return;
    await deleteDoc(doc(db, 'categories', id));
  };

  const uploadImage = async (file, pathPrefix) => {
    const path = `public/${pathPrefix}/${Date.now()}_${file.name}`;
    const storageRef = ref(storage, path);
    await uploadBytes(storageRef, file);
    return getDownloadURL(storageRef);
  };

  const clampRating = (value) => {
    const n = Number(value);
    if (Number.isNaN(n)) return 4.5;
    return Math.min(5, Math.max(0, n));
  };

  const openAddModal = () => {
    setEditingId(null);
    setEditingImageUrl('');
    setItemForm(EMPTY_FORM);
    setModalOpen(true);
  };

  const openEditModal = (item) => {
    setEditingId(item.id);
    setEditingImageUrl(item.imageUrl || '');
    setItemForm({
      name: item.name || '',
      description: item.description || '',
      price: String(item.price ?? ''),
      rating: String(item.rating ?? '4.5'),
      categoryId: item.categoryId || '',
      file: null,
    });
    setModalOpen(true);
  };

  const closeModal = () => {
    if (saving) return;
    setModalOpen(false);
    setEditingId(null);
    setEditingImageUrl('');
    setItemForm(EMPTY_FORM);
  };

  const saveItem = async (e) => {
    e.preventDefault();
    if (!itemForm.name || !itemForm.price || !itemForm.categoryId) {
      alert('Name, price and category are required.');
      return;
    }
    setSaving(true);
    try {
      let imageUrl = editingId ? editingImageUrl : '';
      if (itemForm.file) {
        imageUrl = await uploadImage(itemForm.file, 'menu-items');
      }

      const data = {
        name: itemForm.name,
        description: itemForm.description,
        price: Number(itemForm.price),
        imageUrl,
        categoryId: itemForm.categoryId,
        rating: clampRating(itemForm.rating),
      };

      if (editingId) {
        await updateDoc(doc(db, 'menuItems', editingId), data);
      } else {
        // This is what makes the new product show up on the customer app's
        // Menu tab — it reads this same "menuItems" collection live.
        await addDoc(collection(db, 'menuItems'), {
          ...data,
          isAvailable: true,
          sortOrder: items.length + 1,
        });
      }

      setModalOpen(false);
      setEditingId(null);
      setEditingImageUrl('');
      setItemForm(EMPTY_FORM);
    } finally {
      setSaving(false);
    }
  };

  const toggleAvailability = async (item) => {
    await updateDoc(doc(db, 'menuItems', item.id), { isAvailable: !item.isAvailable });
  };

  const deleteItem = async (id) => {
    if (!confirm('Delete this menu item?')) return;
    if (editingId === id) closeModal();
    await deleteDoc(doc(db, 'menuItems', id));
  };

  return (
    <Layout>
      <div className="page-header page-header-row">
        <div>
          <h1>Menu</h1>
          <p className="muted">Toggle availability instantly, or add/edit/remove items and categories.</p>
        </div>
        <button className="icon-btn" title="Add product" onClick={openAddModal}>
          +
        </button>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2>Categories</h2>
        <form className="inline-form" onSubmit={addCategory}>
          <input
            placeholder="New category name (e.g. Burgers)"
            value={newCategory}
            onChange={(e) => setNewCategory(e.target.value)}
          />
          <button className="btn primary" type="submit">Add</button>
        </form>
        <div className="chip-row">
          {categories.map((c) => (
            <span className="chip" key={c.id}>
              {c.name}
              <button className="chip-x" onClick={() => deleteCategory(c.id)}>×</button>
            </span>
          ))}
          {categories.length === 0 && <span className="muted">No categories yet.</span>}
        </div>
      </div>

      <div className="card">
        <h2>All items</h2>
        <table className="table">
          <thead>
            <tr>
              <th>Photo</th>
              <th>Name</th>
              <th>Category</th>
              <th>Price</th>
              <th>Rating</th>
              <th>Available</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>
                  {item.imageUrl ? (
                    <img src={item.imageUrl} alt={item.name} className="preview-img" />
                  ) : (
                    <span className="muted">—</span>
                  )}
                </td>
                <td>{item.name}</td>
                <td>{categories.find((c) => c.id === item.categoryId)?.name || '—'}</td>
                <td>₹{item.price}</td>
                <td>
                  <span className="stars">★</span> {Number(item.rating ?? 0).toFixed(1)}
                </td>
                <td>
                  <label className="switch">
                    <input
                      type="checkbox"
                      checked={item.isAvailable}
                      onChange={() => toggleAvailability(item)}
                    />
                    <span className="slider" />
                  </label>
                </td>
                <td style={{ display: 'flex', gap: 6 }}>
                  <button className="btn ghost small" onClick={() => openEditModal(item)}>Edit</button>
                  <button className="btn ghost small" onClick={() => deleteItem(item.id)}>Delete</button>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
                  No items yet — tap the + button above to add your first product.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {modalOpen && (
        <div className="modal-overlay" onClick={closeModal}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{editingId ? 'Edit product' : 'Add product'}</h2>
              <button className="modal-close" onClick={closeModal} disabled={saving}>×</button>
            </div>
            <p className="muted" style={{ marginTop: -6 }}>
              Set the photo and rating below, then Save — it appears in the Bamas app's Menu tab right away.
            </p>
            <form className="item-form" onSubmit={saveItem}>
              <input
                placeholder="Item name"
                value={itemForm.name}
                onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })}
              />
              <input
                placeholder="Description"
                value={itemForm.description}
                onChange={(e) => setItemForm({ ...itemForm, description: e.target.value })}
              />
              <input
                type="number"
                placeholder="Price (₹)"
                value={itemForm.price}
                onChange={(e) => setItemForm({ ...itemForm, price: e.target.value })}
              />
              <input
                type="number"
                step="0.1"
                min="0"
                max="5"
                placeholder="Rating (0–5)"
                value={itemForm.rating}
                onChange={(e) => setItemForm({ ...itemForm, rating: e.target.value })}
              />
              <select
                value={itemForm.categoryId}
                onChange={(e) => setItemForm({ ...itemForm, categoryId: e.target.value })}
              >
                <option value="">Select category</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <div />
              <div className="upload-row" style={{ gridColumn: 'span 2' }}>
                {editingImageUrl && (
                  <img src={editingImageUrl} alt="current" className="preview-img" />
                )}
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => setItemForm({ ...itemForm, file: e.target.files[0] })}
                />
              </div>
              <div style={{ display: 'flex', gap: 8, gridColumn: 'span 2' }}>
                <button className="btn primary" type="submit" disabled={saving}>
                  {saving ? 'Saving…' : editingId ? 'Save changes' : 'Save product'}
                </button>
                <button className="btn ghost" type="button" onClick={closeModal} disabled={saving}>
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </Layout>
  );
}
