import React from "react";

const css = `
.mfStatus{display:inline-flex;align-items:center;gap:7px;height:24px;padding:0 10px;border-radius:var(--radius-full);font:var(--weight-medium) var(--text-sm)/1 var(--font-sans);white-space:nowrap}
.mfStatus i{width:7px;height:7px;border-radius:99px;background:currentColor;flex:none}
.mfStatus--queued{background:var(--surface-inset);color:var(--text-2)}
.mfStatus--processing{background:var(--processing-tint);color:var(--processing)}
.mfStatus--processing i{animation:mfPulse 1.6s ease-in-out infinite}
.mfStatus--done{background:var(--ok-tint);color:var(--ok)}
.mfStatus--error{background:var(--err-tint);color:var(--err)}
.mfStatus--offline{background:var(--warn-tint);color:var(--warn)}
@keyframes mfPulse{0%,100%{opacity:1}50%{opacity:.3}}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-status")) {
    const s = document.createElement("style"); s.id = "mf-css-status"; s.textContent = css;
    document.head.appendChild(s);
  }
}

const DEFAULT_LABELS = { queued: "Queued", processing: "Processing…", done: "Filed", error: "Needs attention", offline: "Waiting for network" };

export function StatusBadge({ status = "queued", children, style }) {
  inject();
  return (
    <span className={`mfStatus mfStatus--${status}`} style={style}>
      <i aria-hidden="true"></i>
      {children || DEFAULT_LABELS[status]}
    </span>
  );
}
