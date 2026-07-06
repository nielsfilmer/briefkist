import React from "react";

/* my-flopy — desktop UI kit (web app on the home network). Screens: archive (grid/table),
   document detail (side-by-side), upload (drag & drop), settings/pairing. */

const D = {
  search: (s=18) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.8-3.8"/></svg>,
  grid: (s=16) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/></svg>,
  rows: (s=16) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg>,
  upload: (s=18) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M12 16V4m0 0 5 5m-5-5L7 9"/><path d="M4 20h16"/></svg>,
  back: (s=16) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>,
  gear: (s=18) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M19 5l-2 2M7 17l-2 2"/></svg>,
  wifiOff: (s=40) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 8.8A15 15 0 0 1 12 5c3.8 0 7.3 1.4 10 3.8"/><path d="M5.5 12.5A10 10 0 0 1 12 10c2.5 0 4.8.9 6.5 2.5"/><path d="M9 16.2a5 5 0 0 1 6 0"/><path d="M12 20h.01"/><path d="m3 3 18 18"/></svg>,
  archive: (s=16) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M3 7h18v4H3Z"/><path d="M5 11v9h14v-9"/><path d="M10 15h4"/></svg>,
};

function SideLabel({ children }) {
  return <div style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",letterSpacing:"var(--tracking-caps)",textTransform:"uppercase",color:"var(--text-3)",margin:"22px 0 8px"}}>{children}</div>;
}

/* ── Top bar ────────────────────────────────────────────── */
function TopBar({ query, setQuery, connection, onSettings, showSearch }) {
  return (
    <div style={{display:"flex",alignItems:"center",gap:20,height:60,padding:"0 20px",borderBottom:"1px solid var(--border)",flex:"none"}}>
      <span style={{display:"flex",alignItems:"center",gap:9,flex:"none"}}>
        <Mark size={24}/><span style={{fontFamily:"var(--font-serif)",fontSize:19,fontWeight:600,whiteSpace:"nowrap"}}>my-flopy</span>
      </span>
      <div style={{flex:1,display:"flex",justifyContent:"center"}}>
        {showSearch ? <div style={{width:"100%",maxWidth:540}}><SearchInput value={query} onChange={setQuery}/></div> : null}
      </div>
      <PrivacyMark tone={connection}/>
      <IconButton label="Settings" onClick={onSettings}>{D.gear()}</IconButton>
    </div>
  );
}

/* ── Sidebar ────────────────────────────────────────────── */
function Sidebar({ nav, onNav, cat, setCat, counts }) {
  const navItem = (id, label, icon) => (
    <button key={id} onClick={() => onNav(id)}
      style={{display:"flex",alignItems:"center",gap:10,width:"100%",boxSizing:"border-box",padding:"9px 12px",border:"none",borderRadius:"var(--radius-md)",cursor:"pointer",textAlign:"left",
        background:nav===id?"var(--accent-tint)":"none",color:nav===id?"var(--accent)":"var(--text-2)",font:(nav===id?"600 ":"400 ")+"var(--text-base) var(--font-sans)"}}>
      {icon}{label}
    </button>
  );
  return (
    <div style={{width:230,flex:"none",borderRight:"1px solid var(--border)",padding:"16px 14px",display:"flex",flexDirection:"column",overflowY:"auto"}}>
      <div style={{display:"flex",flexDirection:"column",gap:2}}>
        {navItem("archive","Archive",D.archive())}
        {navItem("upload","Add documents",D.upload(16))}
      </div>
      <SideLabel>Category</SideLabel>
      <div style={{display:"flex",flexDirection:"column",gap:1}}>
        {["all","government","medical","insurance","telecom","employment","housing"].map((c) => (
          <button key={c} onClick={() => setCat(c)}
            style={{display:"flex",alignItems:"center",gap:8,padding:"6px 12px",border:"none",borderRadius:"var(--radius-md)",cursor:"pointer",textAlign:"left",
              background:cat===c?"var(--surface-hover)":"none",color:cat===c?"var(--text-1)":"var(--text-2)",font:"var(--text-sm) var(--font-sans)"}}>
            <span style={{flex:1}}>{c==="all"?"All categories":c}</span>
            <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>{counts[c]||""}</span>
          </button>
        ))}
      </div>
      <SideLabel>Correspondent</SideLabel>
      <Select placeholder="Any" options={["Belastingdienst","Zilveren Kruis","UMC Utrecht","Ziggo","Stadt Köln"]} onChange={() => {}} style={{width:"100%"}}/>
      <SideLabel>Date range</SideLabel>
      <div style={{display:"flex",flexDirection:"column",gap:8}}>
        <TextField value="Jan 2026" onChange={() => {}}/>
        <TextField value="Jul 2026" onChange={() => {}}/>
      </div>
      <div style={{marginTop:"auto",paddingTop:26}}>
        <PrivacyMark tone="ok">mini.local · connected</PrivacyMark>
      </div>
    </div>
  );
}

/* ── Archive content ────────────────────────────────────── */
function ArchiveContent({ state, docs, density, setDensity, onOpen, onRetry, onGoUpload, query }) {
  if (state === "offline") return (
    <div style={{flex:1,display:"grid",placeItems:"center"}}>
      <EmptyState title="Can't reach your home server" icon={<span style={{color:"var(--warn)"}}>{D.wifiOff(44)}</span>}
        action={<Button variant="secondary" onClick={onRetry}>Try again</Button>}>
        Your archive lives only on your own server. Check the VPN connection and try again — nothing is stored anywhere else.
      </EmptyState>
    </div>);
  if (state === "empty") return (
    <div style={{flex:1,display:"grid",placeItems:"center"}}>
      <EmptyState title="Nothing filed yet" action={<Button icon={D.upload()} onClick={onGoUpload}>Add your first letter</Button>}>
        Drop a scan here, or photograph a letter with your phone.
      </EmptyState>
    </div>);
  const toolbar = (
    <div style={{display:"flex",alignItems:"center",gap:12,padding:"14px 22px 4px"}}>
      <span style={{fontSize:"var(--text-sm)",color:"var(--text-2)",whiteSpace:"nowrap"}}>
        {state === "loading" ? "Searching…" : `${docs.length} document${docs.length===1?"":"s"}`}{query ? <span> · matching “{query}” by words and meaning</span> : null}
      </span>
      <span style={{flex:1}}></span>
      <span style={{display:"inline-flex",border:"1px solid var(--border-strong)",borderRadius:"var(--radius-md)",overflow:"hidden"}}>
        {[["grid",D.grid()],["table",D.rows()]].map(([m, icon]) => (
          <button key={m} onClick={() => setDensity(m)} aria-label={m+" view"}
            style={{border:"none",padding:"7px 10px",cursor:"pointer",display:"grid",placeItems:"center",background:density===m?"var(--accent-tint)":"var(--surface-card)",color:density===m?"var(--accent)":"var(--text-3)"}}>{icon}</button>
        ))}
      </span>
    </div>
  );
  let body;
  if (state === "loading") {
    body = (
      <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(230px,1fr))",gap:14,padding:"14px 22px"}}>
        {Array.from({length:6}).map((_, i) => (
          <div key={i} style={{height:210,background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)",animation:"mfPulse 1.6s ease-in-out infinite"}}></div>
        ))}
      </div>);
  } else if (!docs.length) {
    body = <EmptyState title="No matches">Nothing matches “{query}”. Try describing the letter instead — search also looks at meaning.</EmptyState>;
  } else if (density === "grid") {
    body = (
      <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(230px,1fr))",gap:14,padding:"14px 22px 28px"}}>
        {docs.map((d) => <DocumentCard key={d.id} doc={d} density="grid" onOpen={() => onOpen(d)}/>)}
      </div>);
  } else {
    const th = {textAlign:"left",fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",letterSpacing:"var(--tracking-caps)",textTransform:"uppercase",color:"var(--text-3)",fontWeight:400,padding:"10px 14px",borderBottom:"1px solid var(--border)"};
    const td = {padding:"11px 14px",borderBottom:"1px solid var(--border)",fontSize:"var(--text-sm)",color:"var(--text-2)",verticalAlign:"middle"};
    body = (
      <div style={{padding:"14px 22px 28px"}}>
        <div style={{background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)",overflow:"hidden"}}>
          <table style={{width:"100%",borderCollapse:"collapse"}}>
            <thead><tr><th style={th}>Title</th><th style={th}>Correspondent</th><th style={th}>Date</th><th style={th}>Category</th><th style={{...th,textAlign:"right"}}>Pages</th></tr></thead>
            <tbody>
              {docs.map((d, i) => (
                <tr key={d.id} onClick={() => onOpen(d)} style={{cursor:"pointer"}}
                  onMouseEnter={(e) => e.currentTarget.style.background = "var(--surface-hover)"}
                  onMouseLeave={(e) => e.currentTarget.style.background = ""}>
                  <td style={{...td,fontFamily:"var(--font-serif)",fontSize:"var(--text-base)",fontWeight:600,color:"var(--text-1)"}}>{d.title}</td>
                  <td style={td}>{d.correspondent}</td>
                  <td style={{...td,fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)"}}>{d.date}</td>
                  <td style={td}><Chip>{d.category}</Chip></td>
                  <td style={{...td,textAlign:"right",fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)"}}>{d.pages}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>);
  }
  return <div style={{flex:1,minWidth:0,overflowY:"auto",display:"flex",flexDirection:"column"}}>{toolbar}{body}</div>;
}

/* ── Detail ─────────────────────────────────────────────── */
function DetailContent({ doc, corrections, onSave, onBack }) {
  const [page, setPage] = React.useState(0);
  const [mode, setMode] = React.useState("cleaned");
  const val = (k) => (corrections[k] !== undefined ? corrections[k] : doc[k]);
  return (
    <div style={{flex:1,minWidth:0,display:"flex",minHeight:0}}>
      {/* image panel */}
      <div style={{flex:"1 1 46%",minWidth:340,borderRight:"1px solid var(--border)",background:"var(--surface-inset)",display:"flex",flexDirection:"column",padding:18,gap:14,overflowY:"auto"}}>
        <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <span style={{display:"inline-flex",borderRadius:"var(--radius-full)",background:"var(--surface-card)",border:"1px solid var(--border)",padding:3}}>
            {["cleaned","original"].map((m) => (
              <button key={m} onClick={() => setMode(m)} style={{border:"none",borderRadius:"var(--radius-full)",padding:"5px 14px",cursor:"pointer",font:"500 var(--text-sm) var(--font-sans)",background:mode===m?"var(--accent)":"transparent",color:mode===m?"var(--text-on-accent)":"var(--text-2)"}}>{m}</button>
            ))}
          </span>
          <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>page {page+1} of {doc.pages} · {mode}</span>
        </div>
        <div style={{flex:1,display:"grid",placeItems:"center"}}>
          <PageThumb pageNumber={page+1} style={{width:"78%",maxWidth:420,aspectRatio:"3/4",height:"auto"}}/>
        </div>
        <div style={{display:"flex",gap:8,justifyContent:"center"}}>
          {Array.from({length:doc.pages}).map((_, i) => (
            <PageThumb key={i} pageNumber={i+1} width={44} height={58} onClick={() => setPage(i)}
              style={i===page?{outline:"2px solid var(--accent)",outlineOffset:1}:undefined}/>
          ))}
        </div>
      </div>
      {/* metadata panel */}
      <div style={{flex:"1 1 54%",minWidth:0,overflowY:"auto",padding:"18px 26px 30px"}}>
        <button onClick={onBack} style={{display:"inline-flex",alignItems:"center",gap:6,border:"none",background:"none",color:"var(--text-2)",font:"var(--text-sm) var(--font-sans)",cursor:"pointer",padding:"4px 6px",margin:"0 0 10px -6px",borderRadius:"var(--radius-sm)"}}>{D.back()} Archive</button>
        <h1 style={{fontFamily:"var(--font-serif)",fontSize:"var(--text-2xl)",lineHeight:1.25,fontWeight:600,margin:"0 0 10px"}}>{val("title")}</h1>
        <p style={{fontSize:"var(--text-base)",lineHeight:"var(--leading-base)",color:"var(--text-2)",margin:"0 0 20px",maxWidth:560}}>{doc.summary}</p>
        <div style={{background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)",padding:"2px 16px"}}>
          <MetaRow label="correspondent" value={`${val("correspondent")} · ${doc.place}`} onSave={(v) => onSave("correspondent", v)} corrected={corrections.correspondent !== undefined}/>
          <MetaRow label="recipient" value={val("recipient")} onSave={(v) => onSave("recipient", v)} corrected={corrections.recipient !== undefined}/>
          <MetaRow label="document date" value={val("date")} mono onSave={(v) => onSave("date", v)} corrected={corrections.date !== undefined}/>
          <MetaRow label="category" editable={false}><Chip>{doc.category}</Chip></MetaRow>
          <MetaRow label="reference" value={val("reference")} mono onSave={(v) => onSave("reference", v)} corrected={corrections.reference !== undefined}/>
          <MetaRow label="language" value={doc.language} onSave={(v) => onSave("language", v)} corrected={corrections.language !== undefined}/>
          <MetaRow label="subject" value={val("subject")} onSave={(v) => onSave("subject", v)} corrected={corrections.subject !== undefined}/>
        </div>
        <SideLabel>Keywords</SideLabel>
        <div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
          {doc.keywords.map((k) => <Chip key={k}>{k}</Chip>)}
        </div>
        <div style={{marginTop:22}}><PrivacyMark/></div>
      </div>
    </div>
  );
}

/* ── Upload ─────────────────────────────────────────────── */
function UploadContent({ onDone }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div style={{flex:1,minWidth:0,overflowY:"auto",padding:"22px 26px 30px"}}>
      <div
        onDragOver={(e) => { e.preventDefault(); setHover(true); }}
        onDragLeave={() => setHover(false)}
        onDrop={(e) => { e.preventDefault(); setHover(false); onDone(); }}
        style={{border:"1.5px dashed " + (hover ? "var(--accent)" : "var(--border-strong)"),background:hover?"var(--accent-tint)":"var(--surface-card)",borderRadius:"var(--radius-xl)",padding:"52px 24px",display:"flex",flexDirection:"column",alignItems:"center",gap:12,textAlign:"center",transition:"all .15s ease-out"}}>
        <span style={{width:56,height:56,borderRadius:999,background:"var(--accent-tint)",color:"var(--accent)",display:"grid",placeItems:"center"}}>{D.upload(26)}</span>
        <div style={{fontFamily:"var(--font-serif)",fontSize:"var(--text-lg)",fontWeight:600}}>Drop letter scans here</div>
        <div style={{fontSize:"var(--text-sm)",color:"var(--text-2)"}}>Photos or PDFs · multiple pages become one document</div>
        <Button variant="secondary" onClick={onDone}>Browse files</Button>
        <PrivacyMark>uploads go to your server only</PrivacyMark>
      </div>
      <SideLabel>Recent uploads</SideLabel>
      <div style={{background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)"}}>
        {UPLOADS.map((u, i) => (
          <div key={u.id} style={{display:"flex",alignItems:"center",gap:14,padding:"11px 16px",borderTop:i?"1px solid var(--border)":"none"}}>
            <PageThumb width={34} height={44}/>
            <span style={{flex:1,fontSize:"var(--text-base)",fontWeight:u.title?600:400,fontFamily:u.title?"var(--font-serif)":"var(--font-sans)"}}>{u.title || "Letter"}</span>
            <StatusBadge status={u.status}>{u.statusLabel}</StatusBadge>
            <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)",width:70,textAlign:"right"}}>{u.time}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── Settings ───────────────────────────────────────────── */
function SettingsContent({ onBack }) {
  const card = {background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)"};
  return (
    <div style={{flex:1,minWidth:0,overflowY:"auto",padding:"22px 26px 30px",maxWidth:720}}>
      <button onClick={onBack} style={{display:"inline-flex",alignItems:"center",gap:6,border:"none",background:"none",color:"var(--text-2)",font:"var(--text-sm) var(--font-sans)",cursor:"pointer",padding:"4px 6px",margin:"0 0 8px -6px",borderRadius:"var(--radius-sm)"}}>{D.back()} Archive</button>
      <h1 style={{fontFamily:"var(--font-serif)",fontSize:"var(--text-2xl)",lineHeight:1.25,fontWeight:600,margin:"0 0 18px"}}>Settings</h1>

      <SideLabel>Pair a device</SideLabel>
      <div style={{...card,padding:20,display:"flex",gap:22,alignItems:"center"}}>
        <div style={{width:150,height:150,flex:"none",borderRadius:"var(--radius-md)",border:"1px solid var(--border-strong)",background:"repeating-linear-gradient(-45deg,var(--surface-card),var(--surface-card) 6px,var(--surface-inset) 6px,var(--surface-inset) 7px)",display:"grid",placeItems:"center"}}>
          <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",background:"var(--surface-card)",padding:"2px 8px",borderRadius:4,color:"var(--text-3)"}}>QR code</span>
        </div>
        <div style={{display:"flex",flexDirection:"column",gap:8}}>
          <div style={{fontWeight:600,fontSize:"var(--text-md)"}}>Scan with your phone</div>
          <div style={{fontSize:"var(--text-sm)",lineHeight:"var(--leading-sm)",color:"var(--text-2)",maxWidth:340}}>
            Open my-flopy on the phone and scan this code. Each device gets its own token; revoke it here any time. The code only works on your home network.
          </div>
          <div style={{display:"flex",gap:10,alignItems:"center",marginTop:4}}>
            <Button variant="secondary" size="sm">Show token instead</Button>
            <PrivacyMark/>
          </div>
        </div>
      </div>

      <SideLabel>Paired devices</SideLabel>
      <div style={card}>
        {[["This computer","paired 2 Jan 2026"],["Phone · Jasmijn","paired 2 Jan 2026"],["Kitchen iPad","paired 14 Feb 2026"]].map(([name, when], i) => (
          <div key={name} style={{display:"flex",alignItems:"center",gap:12,padding:"11px 16px",borderTop:i?"1px solid var(--border)":"none"}}>
            <span style={{flex:1,fontSize:"var(--text-base)"}}>{name}</span>
            <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>{when}</span>
            {i > 0 ? <Button variant="destructive" size="sm">Revoke</Button> : <span style={{fontSize:"var(--text-sm)",color:"var(--text-3)"}}>this device</span>}
          </div>
        ))}
      </div>

      <SideLabel>Server</SideLabel>
      <div style={{...card,padding:"14px 16px",display:"flex",alignItems:"center",gap:12}}>
        <span style={{flex:1,display:"flex",flexDirection:"column",gap:2}}>
          <span style={{fontWeight:600}}>mini.local</span>
          <span style={{fontSize:"var(--text-sm)",color:"var(--text-2)"}}>Cleaning, OCR, extraction and search run here — never anywhere else.</span>
        </span>
        <PrivacyMark tone="ok">connected · home</PrivacyMark>
      </div>

      <SideLabel>Preferences</SideLabel>
      <div style={{...card,padding:16,display:"flex",gap:24,flexWrap:"wrap"}}>
        <Select label="Appearance" options={["Light","Dark","System"]} value="Light" onChange={() => {}}/>
        <Select label="Language" options={["English","Nederlands","Deutsch"]} value="English" onChange={() => {}}/>
      </div>
    </div>
  );
}

/* ── App shell ──────────────────────────────────────────── */
export function DesktopApp({ dark, screen, archiveState, onNavigate }) {
  const [query, setQuery] = React.useState("");
  const [cat, setCat] = React.useState("all");
  const [density, setDensity] = React.useState("grid");
  const [doc, setDoc] = React.useState(null);
  const [corrections, setCorrections] = React.useState({});
  const [toast, setToast] = React.useState(null);
  const timer = React.useRef(null);
  const say = (m) => { setToast(m); if (timer.current) clearTimeout(timer.current); timer.current = setTimeout(() => setToast(null), 2600); };

  React.useEffect(() => { setDoc(null); }, [screen]);

  const counts = DOCS.reduce((a, d) => { a[d.category] = (a[d.category]||0)+1; a.all=(a.all||0)+1; return a; }, {});
  const docs = DOCS.filter((d) =>
    (cat === "all" || d.category === cat) &&
    (!query || (d.title + " " + d.correspondent + " " + d.keywords.join(" ") + " " + d.summary).toLowerCase().includes(query.toLowerCase()))
  );
  const connection = archiveState === "offline" ? "warn" : "ok";

  let main;
  if (doc) main = <DetailContent doc={doc} corrections={corrections} onBack={() => setDoc(null)}
    onSave={(k, v) => { setCorrections({ ...corrections, [k]: v }); say("Saved."); }}/>;
  else if (screen === "settings") main = <SettingsContent onBack={() => onNavigate("archive")}/>;
  else if (screen === "upload") main = <UploadContent onDone={() => say("2 files uploading to your server.")}/>;
  else main = <ArchiveContent state={archiveState} docs={docs} density={density} setDensity={setDensity}
    onOpen={setDoc} onRetry={() => say("Still no route to mini.local.")} onGoUpload={() => onNavigate("upload")} query={query}/>;

  return (
    <div data-theme={dark ? "dark" : undefined} data-screen-label={doc ? "Desktop · document detail" : "Desktop · " + screen}
      style={{width:"100%",height:"100%",display:"flex",flexDirection:"column",background:"var(--surface-page)",color:"var(--text-1)",fontFamily:"var(--font-sans)",position:"relative",overflow:"hidden"}}>
      <TopBar query={query} setQuery={setQuery} connection={connection} onSettings={() => onNavigate("settings")} showSearch={!doc && screen === "archive" && archiveState !== "empty" && archiveState !== "offline"}/>
      <div style={{flex:1,display:"flex",minHeight:0}}>
        {!doc && screen !== "settings" ? <Sidebar nav={screen} onNav={onNavigate} cat={cat} setCat={setCat} counts={counts}/> : null}
        {main}
      </div>
      {toast ? (
        <div style={{position:"absolute",left:0,right:0,bottom:22,display:"flex",justifyContent:"center",pointerEvents:"none"}}>
          <Toast tone="ok">{toast}</Toast>
        </div>
      ) : null}
    </div>
  );
}

/* ── Kit page (chrome + canvas) ─────────────────────────── */
export function DesktopKit() {
  const [dark, setDark] = React.useState(false);
  const [screen, setScreen] = React.useState("archive");
  const [archiveState, setArchiveState] = React.useState("populated");
  const chip = (active) => ({
    border:"1px solid " + (active ? "var(--accent)" : "var(--border-strong)"),
    background: active ? "var(--accent-tint)" : "var(--surface-card)",
    color: active ? "var(--accent)" : "var(--text-2)",
    borderRadius:"var(--radius-full)",padding:"6px 14px",cursor:"pointer",
    font:"500 var(--text-sm) var(--font-sans)",
  });
  return (
    <div style={{minHeight:"100vh",background:"var(--surface-page)",fontFamily:"var(--font-sans)",display:"flex",flexDirection:"column",alignItems:"center",gap:16,padding:"24px 20px 44px",boxSizing:"border-box"}}>
      <div style={{display:"flex",flexWrap:"wrap",gap:8,justifyContent:"center",alignItems:"center"}}>
        {[["archive","Archive"],["upload","Upload"],["settings","Settings"]].map(([id, label]) =>
          <button key={id} style={chip(screen===id)} onClick={() => setScreen(id)}>{label}</button>)}
        <span style={{width:1,height:22,background:"var(--border-strong)",margin:"0 4px"}}></span>
        <button style={chip(dark)} onClick={() => setDark(!dark)}>{dark ? "dark ●" : "dark ○"}</button>
        {screen === "archive" ? (
          <React.Fragment>
            <span style={{width:1,height:22,background:"var(--border-strong)",margin:"0 4px"}}></span>
            {["populated","loading","empty","offline"].map((s) =>
              <button key={s} style={chip(archiveState===s)} onClick={() => setArchiveState(s)}>{s}</button>)}
          </React.Fragment>
        ) : null}
      </div>
      <div style={{width:"min(1280px, 96vw)",height:800,borderRadius:12,overflow:"hidden",border:"1px solid var(--border-strong)",boxShadow:"var(--shadow-overlay)"}}>
        <DesktopApp dark={dark} screen={screen} archiveState={archiveState} onNavigate={setScreen}/>
      </div>
      <div style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>my-flopy · desktop UI kit · click cards or table rows to open the document</div>
    </div>
  );
}
