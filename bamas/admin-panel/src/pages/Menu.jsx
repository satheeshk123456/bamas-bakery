import { useEffect, useState } from 'react';
import {
  addDoc, collection, deleteDoc, doc, onSnapshot, orderBy, query, updateDoc,
} from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../firebase.js';
import Layout from '../components/Layout.jsx';

export default function Menu() {
  const [categories, setCategories] = useState([]);
  const [items, setItems] = useState([]);
  const [newCategory, setNewCategory] = useState('');
  const [itemForm, setItemForm] = useState({ name: '', description: '', price: '', categoryId: '', file: null });
  const [saving, setSaving] = useState(false);

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

  const addItem = async (e) => {
    e.preventDefault();
    if (!itemForm.name || !itemForm.price || !itemForm.categoryId) {
      alert('Name, price and category are required.');
      return;
    }
    setSaving(true);
    try {
      let imageUrl = '';
      if (itemForm.file) {
        imageUrl = await uploadImage(itemForm.file, 'menu-items');
      }
      await addDoc(collection(db, 'menuItems'), {
        name: itemForm.name,
        description: itemForm.description,
        price: Number(itemForm.price),
        imageUrl,
        categoryId: itemForm.categoryId,
        isAvailable: true,
        rating: 4.5,
        sortOrder: items.length + 1,
      });
      setItemForm({ name: '', description: '', price: '', categoryId: '', file: null });
      e.target.reset();
    } finally {
      setSaving(false);
    }
  };

  const toggleAvailability = async (item) => {
    await updateDoc(doc(db, 'menuItems', item.id), { isAvailable: !item.isAvailable });
  };

  const deleteItem = async (id) => {
    if (!confirm('Delete this menu item?')) return;
    await deleteDoc(doc(db, 'menuItems', id));
  };

  return (
    <Layout>
      <div className="page-header">
        <h1>Menu</h1>
        <p className="muted">Toggle availability instantly, or add/remove items and categories.</p>
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

      <div className="card" style={{ marginBottom: 24 }}>
        <h2>Add a menu item</h2>
        <form className="item-form" onSubmit={addItem}>
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
          <select
            value={itemForm.categoryId}
            onChange={(e) => setItemForm({ ...itemForm, categoryId: e.target.value })}
          >
            <option value="">Select category</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <input type="file" accept="image/*" onChange={(e) => setItemForm({ ...itemForm, file: e.target.files[0] })} />
          <button className="btn primary" type="submit" disabled={saving}>
            {saving ? 'Saving…' : 'Add Item'}
          </button>
        </form>
      </div>

      <div className="card">
        <h2>All items</h2>
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Category</th>
              <th>Price</th>
              <th>Available</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>{item.name}</td>
                <td>{categories.find((c) => c.id === item.categoryId)?.name || '—'}</td>
                <td>₹{item.price}</td>
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
                <td>
                  <button className="btn ghost small" onClick={() => deleteItem(item.id)}>Delete</button>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr><td colSpan={5} className="muted">No items yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </Layout>
  );
}
