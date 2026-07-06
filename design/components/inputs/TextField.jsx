import React from "react";

const css = `
.mfField{display:flex;flex-direction:column;gap:6px}
.mfField label{font-size:var(--text-sm);font-weight:var(--weight-semibold);color:var(--text-2)}
.mfField input,.mfField textarea{box-sizing:border-box;width:100%;padding:10px 12px;border-radius:var(--radius-md);border:1px solid var(--border-strong);background:var(--surface-card);color:var(--text-1);font:var(--text-base)/var(--leading-base) var(--font-sans)}
.mfField input{height:40px}
.mfField input:focus,.mfField textarea:focus{outline:2px solid var(--focus-ring);outline-offset:1px;border-color:transparent}
.mfField--err input,.mfField--err textarea{border-color:var(--err)}
.mfField .mfField-msg{font-size:var(--text-sm);color:var(--text-3)}
.mfField--err .mfField-msg{color:var(--err)}
.mfField--mono input{font-family:var(--font-mono);font-size:var(--text-sm)}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-field")) {
    const s = document.createElement("style"); s.id = "mf-css-field"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function TextField({ label, message, error, mono, multiline, value, onChange, id, style, ...rest }) {
  inject();
  const uid = id || "tf-" + String(label || "").toLowerCase().replace(/\W+/g, "-");
  const cls = ["mfField", error ? "mfField--err" : "", mono ? "mfField--mono" : ""].join(" ");
  const handle = onChange ? (e) => onChange(e.target.value) : undefined;
  return (
    <div className={cls} style={style}>
      {label ? <label htmlFor={uid}>{label}</label> : null}
      {multiline
        ? <textarea id={uid} rows={3} value={value} onChange={handle} {...rest} />
        : <input id={uid} type="text" value={value} onChange={handle} {...rest} />}
      {message ? <span className="mfField-msg">{message}</span> : null}
    </div>
  );
}
