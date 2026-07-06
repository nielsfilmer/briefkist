import React from "react";

const css = `
.mfSelect{position:relative;display:inline-flex;flex-direction:column;gap:6px}
.mfSelect>label{font-size:var(--text-sm);font-weight:var(--weight-semibold);color:var(--text-2)}
.mfSelect select{appearance:none;-webkit-appearance:none;height:40px;box-sizing:border-box;padding:0 34px 0 12px;border-radius:var(--radius-md);border:1px solid var(--border-strong);background:var(--surface-card);color:var(--text-1);font:var(--text-base)/1 var(--font-sans);cursor:pointer}
.mfSelect select:focus{outline:2px solid var(--focus-ring);outline-offset:1px;border-color:transparent}
.mfSelect .mfSelect-chev{position:absolute;right:12px;bottom:13px;pointer-events:none;color:var(--text-3)}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-select")) {
    const s = document.createElement("style"); s.id = "mf-css-select"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function Select({ label, options = [], value, onChange, placeholder, id, style, ...rest }) {
  inject();
  const uid = id || "sel-" + String(label || "x").toLowerCase().replace(/\W+/g, "-");
  return (
    <div className="mfSelect" style={style}>
      {label ? <label htmlFor={uid}>{label}</label> : null}
      <select id={uid} value={value ?? ""} onChange={onChange ? (e) => onChange(e.target.value) : undefined} {...rest}>
        {placeholder ? <option value="">{placeholder}</option> : null}
        {options.map((o) => {
          const opt = typeof o === "string" ? { value: o, label: o } : o;
          return <option key={opt.value} value={opt.value}>{opt.label}</option>;
        })}
      </select>
      <svg className="mfSelect-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m6 9 6 6 6-6"/></svg>
    </div>
  );
}
