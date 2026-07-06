import React from "react";

const css = `
.mfThumb{position:relative;background:var(--surface-card);border:1px solid var(--border);border-radius:var(--radius-md);overflow:hidden;display:block}
.mfThumb--btn{cursor:pointer;padding:0}
.mfThumb--btn:hover{border-color:var(--border-strong)}
.mfThumb img{display:block;width:100%;height:100%;object-fit:cover}
.mfThumb-ph{position:absolute;inset:0;display:grid;place-items:center;background:repeating-linear-gradient(-45deg,var(--surface-card),var(--surface-card) 6px,var(--surface-inset) 6px,var(--surface-inset) 7px)}
.mfThumb-ph span{font-family:var(--font-mono);font-size:10px;letter-spacing:0.06em;color:var(--text-3);background:var(--surface-card);padding:2px 6px;border-radius:3px}
.mfThumb-n{position:absolute;right:5px;bottom:5px;background:var(--scrim);color:var(--plum-contrast);font-family:var(--font-mono);font-size:10px;padding:1px 6px;border-radius:var(--radius-sm)}
`;
function inject() {
  if (typeof document !== "undefined" && !document.getElementById("mf-css-thumb")) {
    const s = document.createElement("style"); s.id = "mf-css-thumb"; s.textContent = css;
    document.head.appendChild(s);
  }
}

export function PageThumb({ src, pageNumber, width = 64, height = 84, onClick, alt = "page scan", style }) {
  inject();
  const Tag = onClick ? "button" : "div";
  return (
    <Tag type={onClick ? "button" : undefined} onClick={onClick}
      className={"mfThumb" + (onClick ? " mfThumb--btn" : "")}
      aria-label={onClick ? `Open ${alt}` : undefined}
      style={{ width, height, flex: "none", ...style }}>
      {src ? <img src={src} alt={alt} /> : <div className="mfThumb-ph"><span>page scan</span></div>}
      {pageNumber ? <span className="mfThumb-n">{pageNumber}</span> : null}
    </Tag>
  );
}
