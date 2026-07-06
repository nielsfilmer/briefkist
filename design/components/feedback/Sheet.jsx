import React from "react";

const css = `
.mfSheet-scrim{position:fixed;inset:0;background:var(--scrim);z-index:100;display:flex;align-items:flex-end;justify-content:center}
.mfSheet{background:var(--surface-overlay);border-radius:var(--radius-xl) var(--radius-xl) 0 0;box-shadow:var(--shadow-overlay);width:100%;max-width:560px;box-sizing:border-box;padding:8px 20px 24px;font-family:var(--font-sans);color:var(--text-1);animation:mfSheetUp .24s ease-out}
.mfSheet-grab{width:36px;height:4px;border-radius:99px;background:var(--border-strong);margin:6px auto 14px}
.mfSheet-title{font-family:var(--font-serif);font-size:var(--text-lg);font-weight:var(--weight-semibold);margin:0 0 12px}
@keyframes mfSheetUp{from{transform:translateY(24px);opacity:.6}to{transform:none;opacity:1}}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-sheet")) {
    const s = document.createElement("style"); s.id = "mf-css-sheet"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function Sheet({ open = true, title, children, onClose, inline }) {
  inject();
  if (!open) return null;
  const sheet = (
    <div className="mfSheet" role="dialog" aria-modal={!inline} aria-label={title}>
      <div className="mfSheet-grab" aria-hidden="true"></div>
      {title ? <h2 className="mfSheet-title">{title}</h2> : null}
      {children}
    </div>
  );
  if (inline) return sheet;
  return (
    <div className="mfSheet-scrim" onClick={(e) => { if (e.target === e.currentTarget && onClose) onClose(); }}>
      {sheet}
    </div>
  );
}
