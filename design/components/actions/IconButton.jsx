import React from "react";

const css = `
.mfIconBtn{display:inline-flex;align-items:center;justify-content:center;border:none;background:transparent;color:var(--text-2);border-radius:var(--radius-md);cursor:pointer;transition:background .15s ease-out}
.mfIconBtn:hover{background:var(--surface-hover);color:var(--text-1)}
.mfIconBtn:active{background:var(--surface-pressed)}
.mfIconBtn--md{width:40px;height:40px}
.mfIconBtn--lg{width:44px;height:44px}
.mfIconBtn--sm{width:32px;height:32px}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-iconbutton")) {
    const s = document.createElement("style"); s.id = "mf-css-iconbutton"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function IconButton({ label, size = "md", children, ...rest }) {
  inject();
  return (
    <button type="button" aria-label={label} title={label} className={`mfIconBtn mfIconBtn--${size}`} {...rest}>
      {children}
    </button>
  );
}
