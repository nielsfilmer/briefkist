/* my-flopy web app: capture (phone) + archive (any browser). No framework. */
"use strict";

const $ = (sel) => document.querySelector(sel);

// ---------------------------------------------------------------- auth

const TOKEN_KEY = "flopy_token";
const authHeaders = () => {
  const token = localStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { ...(options.headers || {}), ...authHeaders() },
  });
  if (response.status === 401) {
    $("#settings").showModal();
    throw new Error("Not authorized — set the device token");
  }
  if (!response.ok) {
    let detail = response.statusText;
    try { detail = (await response.json()).detail || detail; } catch { /* keep statusText */ }
    throw new Error(detail);
  }
  return response.json();
}

// ---------------------------------------------------------------- toast

let toastTimer;
function toast(message) {
  const el = $("#toast");
  el.textContent = message;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.hidden = true; }, 3500);
}

// ---------------------------------------------------------------- tabs

function showView(name) {
  $("#view-capture").hidden = name !== "capture";
  $("#view-archive").hidden = name !== "archive";
  $("#tab-capture").classList.toggle("active", name === "capture");
  $("#tab-archive").classList.toggle("active", name === "archive");
  if (location.hash !== `#${name}`) history.replaceState(null, "", `#${name}`);
  if (name === "archive") runSearch();
}
$("#tab-capture").onclick = () => showView("capture");
$("#tab-archive").onclick = () => showView("archive");

// ---------------------------------------------------------------- capture

let pendingFiles = [];

$("#file-input").onchange = (event) => {
  pendingFiles.push(...event.target.files);
  event.target.value = "";
  renderPending();
};
$("#btn-add-page").onclick = () => $("#file-input").click();
$("#btn-clear").onclick = () => { pendingFiles = []; renderPending(); };

function renderPending() {
  const box = $("#pending");
  const previews = $("#page-previews");
  previews.innerHTML = "";
  box.hidden = pendingFiles.length === 0;
  pendingFiles.forEach((file) => {
    const img = document.createElement("img");
    img.src = URL.createObjectURL(file);
    img.onload = () => URL.revokeObjectURL(img.src);
    previews.appendChild(img);
  });
}

$("#btn-upload").onclick = async () => {
  if (!pendingFiles.length) return;
  const form = new FormData();
  pendingFiles.forEach((file) => form.append("files", file));
  $("#btn-upload").disabled = true;
  try {
    const { id } = await api("/api/documents", { method: "POST", body: form });
    toast(`Uploaded — processing #${id}…`);
    pendingFiles = [];
    renderPending();
    trackUpload(id);
  } catch (error) {
    toast(`Upload failed: ${error.message}`);
  } finally {
    $("#btn-upload").disabled = false;
  }
};

const tracked = new Map(); // id -> {status, title}

function renderUploads() {
  const list = $("#upload-list");
  list.innerHTML = "";
  [...tracked.entries()].sort((a, b) => b[0] - a[0]).forEach(([id, doc]) => {
    const item = document.createElement("li");
    item.innerHTML = `
      <div class="card-main">
        <div class="card-title">#${id} ${doc.title || ""}</div>
        <div class="card-sub">${doc.needs_review ? "⚠ needs review — " : ""}${doc.status}</div>
      </div>
      <span class="badge status-${doc.status}">${doc.status}</span>`;
    item.onclick = () => openDetail(id);
    list.appendChild(item);
  });
}

async function trackUpload(id) {
  tracked.set(id, { status: "queued" });
  renderUploads();
  const poll = async () => {
    try {
      const doc = await api(`/api/documents/${id}`);
      tracked.set(id, doc);
      renderUploads();
      if (doc.status === "queued" || doc.status === "processing") {
        setTimeout(poll, 3000);
      } else if (doc.status === "done") {
        toast(doc.needs_review
          ? `#${id} filed — needs review`
          : `#${id} filed: ${doc.title || "done"}`);
      }
    } catch { /* transient; give up silently, list shows last state */ }
  };
  setTimeout(poll, 3000);
}

// ---------------------------------------------------------------- archive

$("#search-form").onsubmit = (event) => { event.preventDefault(); runSearch(); };

async function runSearch() {
  const params = new URLSearchParams();
  const query = $("#search-input").value.trim();
  if (query) params.set("query", query);
  const docType = $("#filter-type").value;
  if (docType) params.set("doc_type", docType);
  if ($("#filter-review").checked) params.set("needs_review", "true");
  try {
    const docs = await api(`/api/documents?${params}`);
    const list = $("#doc-list");
    list.innerHTML = "";
    $("#archive-empty").hidden = docs.length > 0;
    docs.forEach((doc) => list.appendChild(docCard(doc)));
  } catch (error) {
    toast(error.message);
  }
}

function docCard(doc) {
  const item = document.createElement("li");
  const badges = (doc.tags || []).map((t) => `<span class="badge">${escapeHtml(t)}</span>`).join("");
  const review = doc.needs_review ? '<span class="badge review">review</span>' : "";
  const statusBadge = doc.status !== "done"
    ? `<span class="badge status-${doc.status}">${doc.status}</span>` : "";
  item.innerHTML = `
    <img class="thumb" loading="lazy" alt="">
    <div class="card-main">
      <div class="card-title">${escapeHtml(doc.title || `#${doc.id}`)}</div>
      <div class="card-sub">${escapeHtml(doc.correspondent || "")} ${doc.document_date || ""}</div>
      <div>${review}${statusBadge}${badges}</div>
    </div>
    <div class="card-side">
      ${doc.amount_due ? `<div class="amount">€ ${escapeHtml(doc.amount_due)}</div>` : ""}
      ${doc.due_date ? `<div>due ${doc.due_date}</div>` : ""}
    </div>`;
  loadThumb(item.querySelector("img"), doc.id);
  item.onclick = () => openDetail(doc.id);
  return item;
}

async function loadThumb(img, docId) {
  try {
    const response = await fetch(`/api/documents/${docId}/pages/1/image?kind=thumb`, {
      headers: authHeaders(),
    });
    if (response.ok) img.src = URL.createObjectURL(await response.blob());
    else img.remove();
  } catch { img.remove(); }
}

// ---------------------------------------------------------------- detail

const EDITABLE = [
  "title", "correspondent", "doc_type", "document_date", "due_date",
  "amount_due", "iban", "reference",
];

async function openDetail(docId) {
  let doc;
  try { doc = await api(`/api/documents/${docId}`); } catch (error) { toast(error.message); return; }
  $("#d-title").textContent = doc.title || `Document #${doc.id}`;
  const banner = $("#d-review");
  banner.hidden = !doc.needs_review;
  banner.textContent = doc.needs_review ? `⚠ Needs review: ${doc.review_reasons || ""}` : "";

  const fields = $("#d-fields");
  fields.innerHTML = "";
  EDITABLE.forEach((key) => {
    const wrap = document.createElement("div");
    wrap.className = "field";
    const label = document.createElement("label");
    label.textContent = key.replace("_", " ");
    const input = document.createElement("input");
    input.value = doc[key] ?? "";
    input.onchange = async () => {
      input.classList.add("dirty");
      try {
        await api(`/api/documents/${doc.id}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ [key]: input.value || null }),
        });
        input.classList.remove("dirty");
        input.classList.add("saved");
        setTimeout(() => input.classList.remove("saved"), 1500);
      } catch (error) {
        toast(`Save failed: ${error.message}`);
      }
    };
    wrap.append(label, input);
    fields.appendChild(wrap);
  });

  $("#d-tags").innerHTML = (doc.tags || [])
    .map((t) => `<span class="badge">${escapeHtml(t)}</span>`)
    .join("");

  const pages = $("#d-pages");
  pages.innerHTML = "";
  (doc.pages || []).forEach(async (page) => {
    try {
      const response = await fetch(
        `/api/documents/${doc.id}/pages/${page.page_no}/image?kind=cleaned`,
        { headers: authHeaders() },
      );
      if (!response.ok) return;
      const img = document.createElement("img");
      img.src = URL.createObjectURL(await response.blob());
      pages.appendChild(img);
    } catch { /* page image unavailable */ }
  });

  $("#detail").showModal();
}
$("#d-close").onclick = () => $("#detail").close();

// ---------------------------------------------------------------- settings

$("#btn-settings").onclick = () => {
  $("#token-input").value = localStorage.getItem(TOKEN_KEY) || "";
  $("#settings").showModal();
};
$("#token-save").onclick = () => {
  localStorage.setItem(TOKEN_KEY, $("#token-input").value.trim());
  $("#settings").close();
  toast("Token saved");
};
$("#token-cancel").onclick = () => $("#settings").close();

// ---------------------------------------------------------------- util

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = String(text);
  return div.innerHTML;
}

// initial view (deep-linkable: #archive opens the archive tab)
showView(location.hash === "#archive" ? "archive" : "capture");
