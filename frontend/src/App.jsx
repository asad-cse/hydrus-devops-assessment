import { useEffect, useState } from "react";

const API = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

export default function App() {
  const [health, setHealth] = useState(null);
  const [items, setItems] = useState([]);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const loadItems = async () => {
    try {
      const r = await fetch(`${API}/api/items`);
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      setItems(await r.json());
    } catch (e) {
      setError(String(e));
    }
  };

  useEffect(() => {
    fetch(`${API}/health`)
      .then((r) => r.json())
      .then(setHealth)
      .catch((e) => setError(String(e)));
    loadItems();
  }, []);

  const addItem = async () => {
    if (!name.trim()) return;
    setLoading(true);
    setError(null);
    try {
      const r = await fetch(`${API}/api/items`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, description }),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      setName("");
      setDescription("");
      await loadItems();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  const deleteItem = async (id) => {
    await fetch(`${API}/api/items/${id}`, { method: "DELETE" });
    loadItems();
  };

  return (
    <div style={{ fontFamily: "system-ui, sans-serif", padding: 24, maxWidth: 720, margin: "0 auto" }}>
      <h1>Hydrus Demo Application</h1>
      <p>API Base: <code>{API}</code></p>
      <p>
        Backend Health: <code>{JSON.stringify(health)}</code>
      </p>
      {error && (
        <div style={{ background: "#fee", padding: 12, borderRadius: 6, color: "#900" }}>
          Error: {error}
        </div>
      )}

      <hr style={{ margin: "24px 0" }} />

      <h2>Add an Item</h2>
      <div style={{ display: "flex", gap: 8, flexDirection: "column", maxWidth: 480 }}>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Item name"
          style={{ padding: 8 }}
        />
        <input
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Description (optional)"
          style={{ padding: 8 }}
        />
        <button onClick={addItem} disabled={loading} style={{ padding: 10 }}>
          {loading ? "Saving..." : "Add Item"}
        </button>
      </div>

      <h2 style={{ marginTop: 32 }}>Items ({items.length})</h2>
      <ul style={{ listStyle: "none", padding: 0 }}>
        {items.map((it) => (
          <li key={it.id} style={{ padding: 8, borderBottom: "1px solid #eee", display: "flex", justifyContent: "space-between" }}>
            <span>
              <strong>#{it.id}</strong> {it.name}
              {it.description && <em style={{ color: "#666" }}> — {it.description}</em>}
            </span>
            <button onClick={() => deleteItem(it.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
