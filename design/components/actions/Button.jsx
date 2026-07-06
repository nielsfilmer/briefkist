import React from "react";

const css = `
.mfBtn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border-radius:var(--radius-md);font-family:var(--font-sans);font-weight:var(--weight-semibold);cursor:pointer;border:1px solid transparent;transition:background .15s ease-out;white-space:nowrap}
.mfBtn:disabled{opacity:.45;cursor:default}
.mfBtn--md{height:40px;padding:0 16px;font-size:var(--text-base)}
.mfBtn--lg{height:48px;padding:0 22px;font-size:var(--text-md)}
.mfBtn--sm{height:32px;padding:0 12px;font-size:var(--text-sm)}
.mfBtn--primary{background:var(--accent);color:var(--text-on-accent)}
.mfBtn--primary:hover:not(:disabled){background:var(--accent-hover)}
.mfBtn--secondary{background:var(--surface-card);color:var(--text-1);border-color:var(--border-strong)}
.mfBtn--secondary:hover:not(:disabled){background:var(--surface-hover)}
.mfBtn--secondary:active:not(:disabled){background:var(--surface-pressed)}
.mfBtn--destructive{background:transparent;color:var(--err);border-color:var(--err)}
.mfBtn--destructive:hover:not(:disabled){background:var(--err-tint)}
.mfBtn--ghost{background:transparent;color:var(--text-2)}
.mfBtn--ghost:hover:not(:disabled){background:var(--surface-hover);color:var(--text-1)}
.mfBtn--full{width:100%}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-button")) {
    const s = document.createElement("style"); s.id = "mf-css-button"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function Button({ variant = "primary", size = "md", icon, fullWidth, children, ...rest }) {
  inject();
  const cls = ["mfBtn", `mfBtn--${variant}`, `mfBtn--${size}`, fullWidth ? "mfBtn--full" : ""].join(" ");
  return (
    <button type="button" className={cls} {...rest}>
      {icon}
      {children}
    </button>
  );
}
