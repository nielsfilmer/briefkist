import React from "react";

const css = `
.mfToast{display:inline-flex;align-items:center;gap:10px;background:var(--surface-overlay);color:var(--text-1);border:1px solid var(--border);border-radius:var(--radius-lg);box-shadow:var(--shadow-raised);padding:10px 14px;font:var(--text-sm)/var(--leading-sm) var(--font-sans);max-width:360px}
.mfToast svg{flex:none}
.mfToast--ok svg{color:var(--ok)}
.mfToast--error svg{color:var(--err)}
.mfToast-action{border:none;background:none;color:var(--text-link);font:var(--weight-semibold) var(--text-sm) var(--font-sans);cursor:pointer;padding:4px 6px;margin:-4px -2px;border-radius:var(--radius-sm)}
.mfToast-action:hover{background:var(--surface-hover)}
.mfToast--fixed{position:fixed;bottom:24px;left:50%;transform:translateX(-50%);z-index:110;animation:mfToastIn .2s ease-out}
@keyframes mfToastIn{from{transform:translate(-50%,8px);opacity:0}to{transform:translate(-50%,0);opacity:1}}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-toast")) {
    const s = document.createElement("style"); s.id = "mf-css-toast"; s.textContent = css;
    document.head.appendChild(s);
  }
}

const ICONS = {
  ok: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5"/></svg>,
  error: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v5m0 3.5v0"/></svg>,
  info: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5m0-8.5v0"/></svg>,
};

export function Toast({ tone = "info", children, actionLabel, onAction, fixed }) {
  inject();
  return (
    <div className={["mfToast", `mfToast--${tone}`, fixed ? "mfToast--fixed" : ""].join(" ")} role="status">
      {ICONS[tone]}
      <span>{children}</span>
      {actionLabel ? <button type="button" className="mfToast-action" onClick={onAction}>{actionLabel}</button> : null}
    </div>
  );
}
