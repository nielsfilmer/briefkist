import React from "react";

const css = `
.mfSearch{position:relative;display:flex;align-items:center}
.mfSearch svg{position:absolute;left:12px;width:18px;height:18px;color:var(--text-3);pointer-events:none}
.mfSearch input{width:100%;height:44px;box-sizing:border-box;padding:0 14px 0 40px;border-radius:var(--radius-full);border:1px solid var(--border-strong);background:var(--surface-card);color:var(--text-1);font:var(--text-md)/1 var(--font-sans)}
.mfSearch input::placeholder{color:var(--text-3)}
.mfSearch input:focus{outline:2px solid var(--focus-ring);outline-offset:1px;border-color:transparent}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-search")) {
    const s = document.createElement("style"); s.id = "mf-css-search"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function SearchInput({ placeholder = "Search your mail — words or meaning", value, onChange, style, ...rest }) {
  inject();
  return (
    <div className="mfSearch" style={style}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.8-3.8"/></svg>
      <input type="search" placeholder={placeholder} value={value}
        onChange={onChange ? (e) => onChange(e.target.value) : undefined} {...rest} />
    </div>
  );
}
