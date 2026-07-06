import React from "react";
import { StatusBadge } from "./StatusBadge.jsx";
import { Chip } from "./Chip.jsx";
import { PageThumb } from "./PageThumb.jsx";

const css = `
.mfDoc{display:flex;gap:14px;text-align:left;box-sizing:border-box;width:100%;background:var(--surface-card);border:1px solid var(--border);border-radius:var(--radius-lg);padding:14px;cursor:pointer;transition:background .15s ease-out;font-family:var(--font-sans)}
.mfDoc:hover{background:var(--surface-hover)}
.mfDoc:active{background:var(--surface-pressed)}
.mfDoc-body{min-width:0;flex:1;display:flex;flex-direction:column;gap:4px}
.mfDoc-title{font-family:var(--font-serif);font-size:var(--text-md);line-height:1.35;font-weight:var(--weight-semibold);color:var(--text-1);overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}
.mfDoc-sub{font-size:var(--text-sm);color:var(--text-2);display:flex;gap:10px;flex-wrap:wrap;align-items:baseline}
.mfDoc-sub time{font-family:var(--font-mono);font-size:var(--text-xs);color:var(--text-3)}
.mfDoc-foot{display:flex;gap:6px;align-items:center;margin-top:auto;padding-top:6px;flex-wrap:wrap}
.mfDoc--grid{flex-direction:column;gap:10px}
.mfDoc--grid .mfDoc-thumb{width:100%;height:120px}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-doc")) {
    const s = document.createElement("style"); s.id = "mf-css-doc"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function DocumentCard({ doc = {}, density = "list", onOpen }) {
  inject();
  const { title, correspondent, date, category, status = "done", pages = 1, thumbSrc } = doc;
  const processing = status !== "done";
  return (
    <button type="button" className={`mfDoc mfDoc--${density}`} onClick={onOpen}>
      <PageThumb src={thumbSrc} width={density === "grid" ? undefined : 56} height={density === "grid" ? undefined : 74}
        style={density === "grid" ? { width: "100%", height: 120 } : undefined}
        pageNumber={pages > 1 ? pages : undefined} />
      <span className="mfDoc-body">
        <span className="mfDoc-title">{title || (processing ? "Reading your letter…" : "Untitled document")}</span>
        <span className="mfDoc-sub">
          {correspondent ? <span>{correspondent}</span> : null}
          {date ? <time>{date}</time> : null}
        </span>
        <span className="mfDoc-foot">
          {processing ? <StatusBadge status={status} /> : (category ? <Chip>{category}</Chip> : null)}
        </span>
      </span>
    </button>
  );
}
