import React from "react";

const css = `
.mfMeta{display:grid;grid-template-columns:130px 1fr auto;align-items:start;gap:12px;padding:10px 0;border-bottom:1px solid var(--border)}
.mfMeta:last-child{border-bottom:none}
.mfMeta-label{font-family:var(--font-mono);font-size:var(--text-xs);letter-spacing:var(--tracking-caps);text-transform:uppercase;color:var(--text-3);padding-top:3px}
.mfMeta-value{font-size:var(--text-base);line-height:var(--leading-base);color:var(--text-1);min-width:0;overflow-wrap:anywhere}
.mfMeta-value--mono{font-family:var(--font-mono);font-size:var(--text-sm)}
.mfMeta-value--empty{color:var(--text-3);font-style:italic}
.mfMeta-corrected{display:inline-flex;align-items:center;gap:4px;margin-left:8px;color:var(--ok);font-size:var(--text-xs);font-family:var(--font-mono);white-space:nowrap}
.mfMeta input{box-sizing:border-box;width:100%;padding:6px 10px;border-radius:var(--radius-md);border:1px solid var(--border-strong);background:var(--surface-card);color:var(--text-1);font:var(--text-base)/1.3 var(--font-sans)}
.mfMeta input:focus{outline:2px solid var(--focus-ring);outline-offset:1px;border-color:transparent}
.mfMeta-edit{display:inline-flex;border:none;background:none;padding:6px;margin:-4px 0;cursor:pointer;color:var(--text-3);border-radius:var(--radius-md);opacity:0;transition:opacity .15s}
.mfMeta:hover .mfMeta-edit,.mfMeta-edit:focus-visible{opacity:1}
.mfMeta-edit:hover{background:var(--surface-hover);color:var(--text-1)}
@media (pointer:coarse){.mfMeta-edit{opacity:1}}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-meta")) {
    const s = document.createElement("style"); s.id = "mf-css-meta"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function MetaRow({ label, value, mono, corrected, editable = true, onSave, children }) {
  inject();
  const [editing, setEditing] = React.useState(false);
  const [draft, setDraft] = React.useState(value || "");
  const commit = () => { setEditing(false); if (onSave && draft !== value) onSave(draft); };
  return (
    <div className="mfMeta">
      <span className="mfMeta-label">{label}</span>
      {editing ? (
        <input autoFocus value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => { if (e.key === "Enter") commit(); if (e.key === "Escape") { setDraft(value || ""); setEditing(false); } }} />
      ) : (
        <span className={["mfMeta-value", mono ? "mfMeta-value--mono" : "", !value && !children ? "mfMeta-value--empty" : ""].join(" ")}>
          {children || value || "not detected"}
          {corrected ? (
            <span className="mfMeta-corrected" title="Corrected by you">
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
              corrected
            </span>
          ) : null}
        </span>
      )}
      {editable && !editing ? (
        <button type="button" className="mfMeta-edit" aria-label={`Edit ${label}`}
          onClick={() => { setDraft(value || ""); setEditing(true); }}>
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>
        </button>
      ) : null}
    </div>
  );
}
