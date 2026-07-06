import React from "react";

const css = `
.mfChip{display:inline-flex;align-items:center;gap:6px;height:26px;padding:0 11px;border-radius:var(--radius-full);background:var(--surface-inset);color:var(--text-2);font:var(--text-sm)/1 var(--font-sans);border:1px solid transparent;white-space:nowrap}
.mfChip--interactive{cursor:pointer}
.mfChip--interactive:hover{background:var(--surface-pressed);color:var(--text-1)}
.mfChip--selected{background:var(--accent-tint);color:var(--accent);border-color:var(--accent)}
.mfChip .mfChip-x{display:inline-flex;margin-right:-4px;border:none;background:none;padding:2px;cursor:pointer;color:inherit;border-radius:var(--radius-full)}
.mfChip .mfChip-x:hover{background:var(--surface-pressed)}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-chip")) {
    const s = document.createElement("style"); s.id = "mf-css-chip"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function Chip({ children, selected, onClick, onRemove, style }) {
  inject();
  const cls = ["mfChip", selected ? "mfChip--selected" : "", onClick ? "mfChip--interactive" : ""].join(" ");
  const Tag = onClick ? "button" : "span";
  return (
    <Tag className={cls} style={style} onClick={onClick} type={onClick ? "button" : undefined}>
      {children}
      {onRemove ? (
        <button type="button" className="mfChip-x" aria-label="Remove" onClick={(e) => { e.stopPropagation(); onRemove(); }}>
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>
        </button>
      ) : null}
    </Tag>
  );
}
