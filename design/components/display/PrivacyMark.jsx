import React from "react";

const css = `
.mfPriv{display:inline-flex;align-items:center;gap:7px;font-family:var(--font-mono);font-size:var(--text-xs);letter-spacing:0.04em;color:var(--text-3)}
.mfPriv svg{flex:none}
.mfPriv--ok{color:var(--ok)}
.mfPriv--warn{color:var(--warn)}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-priv")) {
    const s = document.createElement("style"); s.id = "mf-css-priv"; s.textContent = css;
    document.head.appendChild(s);
  }
}

const DEFAULTS = { neutral: "on your server", ok: "connected · home", warn: "away from home network" };

export function PrivacyMark({ tone = "neutral", children, style }) {
  inject();
  return (
    <span className={"mfPriv" + (tone !== "neutral" ? ` mfPriv--${tone}` : "")} style={style}>
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9v11h14V9"/></svg>
      {children || DEFAULTS[tone]}
    </span>
  );
}
