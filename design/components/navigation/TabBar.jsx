import React from "react";

const css = `
.mfTabs{display:flex;background:var(--surface-page);border-top:1px solid var(--border);font-family:var(--font-sans)}
.mfTab{flex:1;min-height:52px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;border:none;background:none;color:var(--text-3);font:var(--text-xs)/1 var(--font-sans);cursor:pointer;padding:8px 0 10px}
.mfTab svg{width:22px;height:22px}
.mfTab--active{color:var(--accent);font-weight:var(--weight-semibold)}
.mfTab:hover:not(.mfTab--active){color:var(--text-2)}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-tabs")) {
    const s = document.createElement("style"); s.id = "mf-css-tabs"; s.textContent = css;
    document.head.appendChild(s);
  }
}

const GLYPHS = {
  capture: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M4 8h3l2-3h6l2 3h3v12H4Z"/><circle cx="12" cy="13" r="3.5"/></svg>,
  archive: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M3 7h18v4H3Z"/><path d="M5 11v9h14v-9"/><path d="M10 15h4"/></svg>,
  settings: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M19 5l-2 2M7 17l-2 2"/></svg>,
};

export function TabBar({ items, active, onSelect }) {
  inject();
  const list = items || [
    { id: "capture", label: "Capture" },
    { id: "archive", label: "Archive" },
    { id: "settings", label: "Settings" },
  ];
  return (
    <nav className="mfTabs" aria-label="Main">
      {list.map((t) => (
        <button key={t.id} type="button"
          className={"mfTab" + (active === t.id ? " mfTab--active" : "")}
          aria-current={active === t.id ? "page" : undefined}
          onClick={onSelect ? () => onSelect(t.id) : undefined}>
          {t.icon || GLYPHS[t.id] || GLYPHS.archive}
          <span>{t.label}</span>
        </button>
      ))}
    </nav>
  );
}
