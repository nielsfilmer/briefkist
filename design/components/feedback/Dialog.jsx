import React from "react";

const css = `
.mfDlg-scrim{position:fixed;inset:0;background:var(--scrim);display:grid;place-items:center;z-index:100;padding:24px}
.mfDlg{background:var(--surface-overlay);border-radius:var(--radius-xl);box-shadow:var(--shadow-overlay);width:100%;max-width:420px;padding:24px;box-sizing:border-box;font-family:var(--font-sans);color:var(--text-1)}
.mfDlg-title{font-family:var(--font-serif);font-size:var(--text-lg);font-weight:var(--weight-semibold);margin:0 0 8px}
.mfDlg-body{font-size:var(--text-base);line-height:var(--leading-base);color:var(--text-2)}
.mfDlg-actions{display:flex;justify-content:flex-end;gap:10px;margin-top:22px}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-dialog")) {
    const s = document.createElement("style"); s.id = "mf-css-dialog"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function Dialog({ open = true, title, children, actions, onClose, inline }) {
  inject();
  if (!open) return null;
  const dlg = (
    <div className="mfDlg" role="dialog" aria-modal={!inline} aria-label={title}>
      {title ? <h2 className="mfDlg-title">{title}</h2> : null}
      <div className="mfDlg-body">{children}</div>
      {actions ? <div className="mfDlg-actions">{actions}</div> : null}
    </div>
  );
  if (inline) return dlg;
  return (
    <div className="mfDlg-scrim" onClick={(e) => { if (e.target === e.currentTarget && onClose) onClose(); }}>
      {dlg}
    </div>
  );
}
