const API_BASE = window.API_BASE || "";

async function refreshStatus() {
  const el = document.getElementById("status");
  try {
    const res = await fetch(`${API_BASE}/health`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    el.textContent = `${data.service}: ${data.status}`;
    el.className = "ok";
  } catch (err) {
    el.textContent = `unreachable (${err.message})`;
    el.className = "fail";
  }
}

async function loadItems() {
  const list = document.getElementById("items");
  list.innerHTML = "";
  try {
    const res = await fetch(`${API_BASE}/items`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const items = await res.json();
    for (const item of items) {
      const li = document.createElement("li");
      li.textContent = `${item.name} — ${item.description}`;
      list.appendChild(li);
    }
  } catch (err) {
    const li = document.createElement("li");
    li.textContent = `failed to load items: ${err.message}`;
    li.className = "fail";
    list.appendChild(li);
  }
}

document.getElementById("refresh").addEventListener("click", () => {
  refreshStatus();
  loadItems();
});

document.getElementById("item-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const name = document.getElementById("name").value.trim();
  const description = document.getElementById("description").value.trim();
  if (!name) return;
  try {
    await fetch(`${API_BASE}/items`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, description }),
    });
    document.getElementById("name").value = "";
    document.getElementById("description").value = "";
    loadItems();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("create failed", err);
  }
});

refreshStatus();
loadItems();
