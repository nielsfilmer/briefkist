import React from "react";

const css = `
.mfEmpty{display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px;padding:40px 24px;color:var(--text-2)}
.mfEmpty-art{color:var(--text-3);opacity:.8;margin-bottom:10px}
.mfEmpty-title{font-family:var(--font-serif);font-size:var(--text-lg);font-weight:var(--weight-semibold);color:var(--text-1)}
.mfEmpty-body{font-size:var(--text-base);line-height:var(--leading-base);max-width:340px}
.mfEmpty-action{margin-top:14px}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-empty")) {
    const s = document.createElement("style"); s.id = "mf-css-empty"; s.textContent = css;
    document.head.appendChild(s);
  }
}

/** Dashed postmark circle + cancellation lines — the brand's empty-state motif. */
function Postmark() {
  return (
    <svg width="150" height="70" viewBox="0 0 120 56" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" aria-hidden="true">
      <circle cx="28" cy="28" r="20" strokeDasharray="4 5" />
      <path d="M56 20c6-4 10 4 16 0s10 4 16 0s10 4 16 0" />
      <path d="M56 28c6-4 10 4 16 0s10 4 16 0s10 4 16 0" />
      <path d="M56 36c6-4 10 4 16 0s10 4 16 0s10 4 16 0" />
    </svg>
  );
}

export function EmptyState({ title, children, action, art = "postmark", icon }) {
  inject();
  return (
    <div className="mfEmpty">
      <div className="mfEmpty-art">{icon || (art === "postmark" ? <Postmark /> : null)}</div>
      <div className="mfEmpty-title">{title}</div>
      {children ? <div className="mfEmpty-body">{children}</div> : null}
      {action ? <div className="mfEmpty-action">{action}</div> : null}
    </div>
  );
}
