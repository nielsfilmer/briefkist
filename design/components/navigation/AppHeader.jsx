import React from "react";
import { PrivacyMark } from "../display/PrivacyMark.jsx";

const css = `
.mfHdr{display:flex;align-items:center;gap:14px;height:56px;padding:0 20px;background:var(--surface-page);border-bottom:1px solid var(--border);box-sizing:border-box;font-family:var(--font-sans)}
.mfHdr-brand{display:flex;align-items:center;gap:9px;color:var(--text-1)}
.mfHdr-word{font-family:var(--font-serif);font-size:19px;font-weight:var(--weight-semibold);white-space:nowrap}
.mfHdr-mark{color:var(--text-1)}
.mfHdr-title{font-family:var(--font-serif);font-size:var(--text-lg);font-weight:var(--weight-semibold);color:var(--text-1);white-space:nowrap;flex:none}
.mfHdr-spacer{flex:1}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-header")) {
    const s = document.createElement("style"); s.id = "mf-css-header"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function Mark({ size = 24, style }) {
  return (
    <svg className="mfHdr-mark" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" style={style}>
      <path d="M4 4h12.5L20 7.5V20H4Z" />
      <path d="M8 4v2.6l4 3 4-3V4" />
      <path d="M8 20v-5.5h8V20" />
    </svg>
  );
}

export function AppHeader({ title, brand = true, connection = "ok", leading, actions }) {
  inject();
  return (
    <header className="mfHdr">
      {leading}
      {brand && !title ? (
        <span className="mfHdr-brand"><Mark /><span className="mfHdr-word">my-flopy</span></span>
      ) : (
        <span className="mfHdr-title">{title}</span>
      )}
      <span className="mfHdr-spacer"></span>
      {connection ? <PrivacyMark tone={connection} /> : null}
      {actions}
    </header>
  );
}
