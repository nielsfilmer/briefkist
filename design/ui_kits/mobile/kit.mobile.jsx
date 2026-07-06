import React from "react";

/* my-flopy — mobile UI kit (phone). Screens: onboarding, capture, archive, detail, settings.
   Composes the design-system primitives; rendered inside the iOS device frame. */

const I = {
  camera: (s=22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M4 8h3l2-3h6l2 3h3v12H4Z"/><circle cx="12" cy="13" r="3.5"/></svg>,
  back: (s=20) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>,
  filter: (s=18) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><path d="M4 6h16M7 12h10M10 18h4"/></svg>,
  plus: (s=20) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>,
  x: (s=18) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>,
  wifiOff: (s=40) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 8.8A15 15 0 0 1 12 5c3.8 0 7.3 1.4 10 3.8"/><path d="M5.5 12.5A10 10 0 0 1 12 10c2.5 0 4.8.9 6.5 2.5"/><path d="M9 16.2a5 5 0 0 1 6 0"/><path d="M12 20h.01"/><path d="m3 3 18 18"/></svg>,
  qr: (s=18) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14h1M14 20h1M20 20h1"/></svg>,
};

function SectionLabel({ children, style }) {
  return <div style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",letterSpacing:"var(--tracking-caps)",textTransform:"uppercase",color:"var(--text-3)",margin:"20px 0 8px",...style}}>{children}</div>;
}
function Card({ children, style }) {
  return <div style={{background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)",...style}}>{children}</div>;
}

/* ── Onboarding ─────────────────────────────────────────── */
function OnboardingScreen({ step, onNext, onDone }) {
  const steps = [
    {
      art: <Mark size={64} style={{color:"var(--accent)"}}/>,
      title: "Your mail stays home.",
      body: "my-flopy turns paper letters into a searchable archive — processed entirely on your own server. No cloud, no telemetry. Nothing ever leaves hardware you own.",
      cta: "Continue",
    },
    {
      art: <span style={{color:"var(--accent)"}}>{I.qr(56)}</span>,
      title: "Pair with your server.",
      body: "Open my-flopy on the computer that runs your archive and scan the code it shows. This phone will talk only to your own server.",
      cta: "Scan the code",
      alt: "or paste a device token",
    },
    {
      art: <span style={{color:"var(--accent)"}}>{I.camera(56)}</span>,
      title: "File your first letter.",
      body: "Photograph each page. Your server cleans the image, reads it, and files it — usually within a minute.",
      cta: "Open the camera",
    },
  ];
  const s = steps[step];
  return (
    <div style={{flex:1,display:"flex",flexDirection:"column",padding:"0 28px 40px"}}>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",textAlign:"center",gap:18}}>
        {s.art}
        <div style={{fontFamily:"var(--font-serif)",fontSize:"var(--text-2xl)",lineHeight:1.25,fontWeight:600}}>{s.title}</div>
        <div style={{fontSize:"var(--text-md)",lineHeight:"var(--leading-md)",color:"var(--text-2)",maxWidth:300}}>{s.body}</div>
        {step === 0 ? <PrivacyMark/> : null}
      </div>
      <div style={{display:"flex",justifyContent:"center",gap:7,margin:"18px 0 22px"}}>
        {steps.map((_, i) => <span key={i} style={{width:7,height:7,borderRadius:99,background:i===step?"var(--accent)":"var(--border-strong)"}}></span>)}
      </div>
      <Button size="lg" fullWidth onClick={step<2?onNext:onDone}>{s.cta}</Button>
      {s.alt ? <button onClick={onNext} style={{marginTop:14,border:"none",background:"none",color:"var(--text-link)",font:"var(--text-base) var(--font-sans)",cursor:"pointer"}}>{s.alt}</button> : null}
    </div>
  );
}

/* ── Capture ────────────────────────────────────────────── */
function CaptureScreen({ uploads, pendingPages, onAddPage, onUpload, onOpenDoc }) {
  return (
    <div style={{flex:1,overflowY:"auto",padding:"12px 16px 24px"}}>
      <Card style={{padding:"26px 20px",display:"flex",flexDirection:"column",alignItems:"center",gap:14,textAlign:"center"}}>
        <span style={{width:64,height:64,borderRadius:999,background:"var(--accent-tint)",color:"var(--accent)",display:"grid",placeItems:"center"}}>{I.camera(30)}</span>
        <div style={{fontFamily:"var(--font-serif)",fontSize:"var(--text-lg)",lineHeight:1.3,fontWeight:600,whiteSpace:"nowrap"}}>Photograph a letter</div>
        <Button size="lg" fullWidth icon={I.camera(18)} onClick={onAddPage}>{pendingPages ? "Add another page" : "Open the camera"}</Button>
        <PrivacyMark>uploads go to your server only</PrivacyMark>
      </Card>

      {pendingPages > 0 ? (
        <React.Fragment>
          <SectionLabel>Pending pages · this letter</SectionLabel>
          <Card style={{padding:14,display:"flex",gap:10,alignItems:"center"}}>
            {Array.from({length:pendingPages}).map((_, i) => <PageThumb key={i} pageNumber={i+1} width={52} height={68}/>)}
            <button onClick={onAddPage} aria-label="Add page" style={{width:52,height:68,borderRadius:"var(--radius-md)",border:"1.5px dashed var(--border-strong)",background:"none",color:"var(--text-3)",cursor:"pointer",display:"grid",placeItems:"center"}}>{I.plus(20)}</button>
            <div style={{flex:1}}></div>
            <Button size="md" onClick={onUpload}>Upload {pendingPages} page{pendingPages>1?"s":""}</Button>
          </Card>
        </React.Fragment>
      ) : null}

      <SectionLabel>Recent uploads</SectionLabel>
      <Card>
        {uploads.map((u, i) => (
          <button key={u.id} onClick={u.status==="done"?onOpenDoc:undefined}
            style={{display:"flex",alignItems:"center",gap:12,width:"100%",boxSizing:"border-box",padding:"12px 14px",border:"none",background:"none",textAlign:"left",cursor:u.status==="done"?"pointer":"default",borderTop:i?"1px solid var(--border)":"none",fontFamily:"var(--font-sans)"}}>
            <PageThumb width={40} height={52}/>
            <span style={{flex:1,minWidth:0,display:"flex",flexDirection:"column",gap:3}}>
              <span style={{fontSize:"var(--text-base)",color:"var(--text-1)",fontWeight:u.title?600:400,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",fontFamily:u.title?"var(--font-serif)":"var(--font-sans)"}}>{u.title || "Letter"}</span>
              <StatusBadge status={u.status}>{u.statusLabel}</StatusBadge>
            </span>
            <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)",flex:"none"}}>{u.time}</span>
          </button>
        ))}
      </Card>
    </div>
  );
}

/* ── Archive ────────────────────────────────────────────── */
function SkeletonCard() {
  return (
    <div style={{display:"flex",gap:14,background:"var(--surface-card)",border:"1px solid var(--border)",borderRadius:"var(--radius-lg)",padding:14,animation:"mfPulse 1.6s ease-in-out infinite"}}>
      <div style={{width:56,height:74,borderRadius:"var(--radius-md)",background:"var(--surface-inset)"}}></div>
      <div style={{flex:1,display:"flex",flexDirection:"column",gap:8,paddingTop:4}}>
        <div style={{height:14,width:"75%",borderRadius:4,background:"var(--surface-inset)"}}></div>
        <div style={{height:11,width:"45%",borderRadius:4,background:"var(--surface-inset)"}}></div>
        <div style={{height:18,width:80,borderRadius:99,background:"var(--surface-inset)",marginTop:"auto"}}></div>
      </div>
    </div>
  );
}

function ArchiveScreen({ state, docs, query, setQuery, cat, setCat, onOpen, onOpenFilters, onRetry, onGoCapture }) {
  const cats = ["all","government","medical","insurance","telecom","housing","employment"];
  const body = () => {
    if (state === "loading") return <div style={{display:"flex",flexDirection:"column",gap:10}}><SkeletonCard/><SkeletonCard/><SkeletonCard/></div>;
    if (state === "offline") return (
      <EmptyState title="Can't reach your home server" icon={<span style={{color:"var(--warn)"}}>{I.wifiOff(44)}</span>}
        action={<Button variant="secondary" onClick={onRetry}>Try again</Button>}>
        You're away from your home network. Your archive lives only on your own server — connect to the VPN to browse it.
      </EmptyState>);
    if (state === "empty") return (
      <EmptyState title="Nothing filed yet" action={<Button size="lg" icon={I.camera(18)} onClick={onGoCapture}>Photograph a letter</Button>}>
        Your first letter is one photo away.
      </EmptyState>);
    if (!docs.length) return (
      <EmptyState title="No matches">
        Nothing in your archive matches “{query}”. Search looks at words and meaning — try describing the letter instead.
      </EmptyState>);
    return (
      <div style={{display:"flex",flexDirection:"column",gap:10}}>
        {docs.map((d) => <DocumentCard key={d.id} doc={{...d, date:d.date}} onOpen={() => onOpen(d)}/>)}
      </div>);
  };
  return (
    <div style={{flex:1,display:"flex",flexDirection:"column",minHeight:0}}>
      {state !== "empty" && state !== "offline" ? (
        <div style={{padding:"10px 16px 4px"}}>
          <div style={{display:"flex",gap:8,alignItems:"center"}}>
            <div style={{flex:1}}><SearchInput value={query} onChange={setQuery}/></div>
            <IconButton label="Filters" size="lg" onClick={onOpenFilters}>{I.filter()}</IconButton>
          </div>
          <div style={{display:"flex",gap:8,overflowX:"auto",padding:"12px 2px 10px",scrollbarWidth:"none"}}>
            {cats.map((c) => <Chip key={c} selected={cat===c} onClick={() => setCat(c)}>{c==="all"?"All":c}</Chip>)}
          </div>
        </div>
      ) : null}
      <div style={{flex:1,overflowY:"auto",padding:"4px 16px 24px"}}>{body()}</div>
    </div>
  );
}

/* ── Detail ─────────────────────────────────────────────── */
function DetailScreen({ doc, corrections, onSave, onOpenViewer }) {
  const val = (k) => (corrections[k] !== undefined ? corrections[k] : doc[k]);
  return (
    <div style={{flex:1,overflowY:"auto",padding:"12px 16px 28px"}}>
      <div style={{display:"flex",gap:10,marginBottom:16}}>
        {Array.from({length:doc.pages}).map((_, i) => <PageThumb key={i} pageNumber={i+1} width={84} height={110} onClick={() => onOpenViewer(i)}/>)}
      </div>
      <h1 style={{fontFamily:"var(--font-serif)",fontSize:"var(--text-xl)",lineHeight:1.3,fontWeight:600,margin:"0 0 10px"}}>{val("title")}</h1>
      <p style={{fontSize:"var(--text-base)",lineHeight:"var(--leading-base)",color:"var(--text-2)",margin:"0 0 18px"}}>{doc.summary}</p>
      <Card style={{padding:"2px 14px"}}>
        <MetaRow label="correspondent" value={`${val("correspondent")} · ${doc.place}`} onSave={(v) => onSave("correspondent", v)} corrected={corrections.correspondent !== undefined}/>
        <MetaRow label="recipient" value={val("recipient")} onSave={(v) => onSave("recipient", v)} corrected={corrections.recipient !== undefined}/>
        <MetaRow label="document date" value={val("date")} mono onSave={(v) => onSave("date", v)} corrected={corrections.date !== undefined}/>
        <MetaRow label="category" editable={false}><Chip>{doc.category}</Chip></MetaRow>
        <MetaRow label="reference" value={val("reference")} mono onSave={(v) => onSave("reference", v)} corrected={corrections.reference !== undefined}/>
        <MetaRow label="language" value={doc.language} onSave={(v) => onSave("language", v)} corrected={corrections.language !== undefined}/>
        <MetaRow label="subject" value={val("subject")} onSave={(v) => onSave("subject", v)} corrected={corrections.subject !== undefined}/>
      </Card>
      <SectionLabel>Keywords</SectionLabel>
      <div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
        {doc.keywords.map((k) => <Chip key={k}>{k}</Chip>)}
      </div>
      <div style={{marginTop:20,display:"flex",justifyContent:"center"}}><PrivacyMark/></div>
    </div>
  );
}

function ImageViewer({ page, mode, setMode, onClose }) {
  return (
    <div style={{position:"absolute",inset:0,background:"var(--scrim)",zIndex:50,display:"flex",flexDirection:"column"}}>
      <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",padding:"14px 14px 0"}}>
        <span style={{display:"inline-flex",borderRadius:"var(--radius-full)",background:"var(--surface-card)",border:"1px solid var(--border)",padding:3}}>
          {["cleaned","original"].map((m) => (
            <button key={m} onClick={() => setMode(m)} style={{border:"none",borderRadius:"var(--radius-full)",padding:"6px 14px",cursor:"pointer",font:"500 var(--text-sm) var(--font-sans)",background:mode===m?"var(--accent)":"transparent",color:mode===m?"var(--text-on-accent)":"var(--text-2)"}}>{m}</button>
          ))}
        </span>
        <IconButton label="Close viewer" size="lg" onClick={onClose} style={{background:"var(--surface-card)",borderRadius:999}}>{I.x()}</IconButton>
      </div>
      <div style={{flex:1,display:"grid",placeItems:"center",padding:20}}>
        <div style={{width:"100%",maxWidth:290,aspectRatio:"3/4",borderRadius:"var(--radius-md)",overflow:"hidden",boxShadow:"var(--shadow-overlay)"}}>
          <PageThumb pageNumber={page+1} width={290} height={387} style={{width:"100%",height:"100%"}}/>
        </div>
      </div>
      <div style={{textAlign:"center",paddingBottom:22,fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--paper-1)"}}>page {page+1} · {mode} scan</div>
    </div>
  );
}

/* ── Settings ───────────────────────────────────────────── */
function SettingsScreen({ onPair, appearance, setAppearance }) {
  const rowS = {display:"flex",alignItems:"center",gap:12,padding:"13px 14px",fontSize:"var(--text-base)"};
  return (
    <div style={{flex:1,overflowY:"auto",padding:"12px 16px 24px"}}>
      <SectionLabel style={{marginTop:6}}>Your server</SectionLabel>
      <Card style={{padding:"16px 14px",display:"flex",alignItems:"center",gap:12}}>
        <span style={{width:40,height:40,borderRadius:"var(--radius-md)",background:"var(--accent-tint)",color:"var(--accent)",display:"grid",placeItems:"center"}}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9v11h14V9"/></svg>
        </span>
        <span style={{flex:1,display:"flex",flexDirection:"column",gap:2}}>
          <span style={{fontWeight:600}}>mini.local</span>
          <span style={{fontSize:"var(--text-sm)",color:"var(--text-2)"}}>All processing happens here.</span>
        </span>
        <PrivacyMark tone="ok" >connected</PrivacyMark>
      </Card>

      <SectionLabel>Devices</SectionLabel>
      <Card>
        <div style={rowS}>
          <span style={{flex:1}}>This phone</span>
          <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>paired 2 Jan 2026</span>
        </div>
        <div style={{...rowS,borderTop:"1px solid var(--border)"}}>
          <span style={{flex:1}}>Kitchen iPad</span>
          <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>paired 14 Feb 2026</span>
        </div>
        <div style={{padding:"12px 14px",borderTop:"1px solid var(--border)"}}>
          <Button variant="secondary" fullWidth icon={I.qr()} onClick={onPair}>Pair a new device</Button>
        </div>
      </Card>

      <SectionLabel>Appearance</SectionLabel>
      <Card style={{padding:12,display:"flex",gap:8}}>
        {["light","dark","system"].map((m) => <Chip key={m} selected={appearance===m} onClick={() => setAppearance(m)}>{m}</Chip>)}
      </Card>

      <SectionLabel>Language</SectionLabel>
      <Card style={{padding:12}}>
        <Select options={["English","Nederlands","Deutsch"]} value="English" onChange={() => {}} style={{width:"100%"}}/>
      </Card>

      <div style={{textAlign:"center",marginTop:24,fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>my-flopy 1.0 · self-hosted</div>
    </div>
  );
}

function PairSheet({ onClose }) {
  return (
    <Sheet inline title="Pair a new device" onClose={onClose}>
      <p style={{margin:"0 0 14px",fontSize:"var(--text-base)",lineHeight:"var(--leading-base)",color:"var(--text-2)"}}>
        On the new device, open my-flopy and scan this code. The device gets its own token — you can revoke it any time.
      </p>
      <div style={{display:"grid",placeItems:"center",padding:"6px 0 14px"}}>
        <div style={{width:160,height:160,borderRadius:"var(--radius-md)",border:"1px solid var(--border-strong)",background:"repeating-linear-gradient(-45deg,var(--surface-card),var(--surface-card) 6px,var(--surface-inset) 6px,var(--surface-inset) 7px)",display:"grid",placeItems:"center"}}>
          <span style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",background:"var(--surface-card)",padding:"2px 8px",borderRadius:4,color:"var(--text-3)"}}>QR code</span>
        </div>
      </div>
      <TextField label="Or share a token" mono value="mfp_9k2c…f41a" onChange={() => {}}/>
      <div style={{display:"flex",justifyContent:"center",margin:"16px 0 4px"}}><PrivacyMark/></div>
    </Sheet>
  );
}

/* ── App shell ──────────────────────────────────────────── */
export function MobilePhone({ dark, screen, archiveState, onNavigate }) {
  const [query, setQuery] = React.useState("");
  const [cat, setCat] = React.useState("all");
  const [detailDoc, setDetailDoc] = React.useState(null);
  const [corrections, setCorrections] = React.useState({});
  const [pendingPages, setPendingPages] = React.useState(2);
  const [obStep, setObStep] = React.useState(0);
  const [showFilters, setShowFilters] = React.useState(false);
  const [showPair, setShowPair] = React.useState(false);
  const [viewer, setViewer] = React.useState(null);
  const [viewerMode, setViewerMode] = React.useState("cleaned");
  const [toast, setToast] = React.useState(null);
  const toastTimer = React.useRef(null);

  React.useEffect(() => { setObStep(0); setDetailDoc(null); setShowPair(false); setShowFilters(false); setViewer(null); }, [screen]);

  const say = (msg) => {
    setToast(msg);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2600);
  };

  const docs = DOCS.filter((d) =>
    (cat === "all" || d.category === cat) &&
    (!query || (d.title + " " + d.correspondent + " " + d.keywords.join(" ") + " " + d.summary).toLowerCase().includes(query.toLowerCase()))
  );

  const showDetail = screen === "archive" && detailDoc;
  const connection = archiveState === "offline" ? "warn" : "ok";

  let content, header = null, tabs = null;
  if (screen === "onboarding") {
    content = <OnboardingScreen step={obStep} onNext={() => setObStep(obStep + 1)} onDone={() => onNavigate("capture")}/>;
  } else if (showDetail) {
    header = <AppHeader title="Document" connection={null} leading={<IconButton label="Back" size="lg" onClick={() => setDetailDoc(null)}>{I.back()}</IconButton>}/>;
    content = <DetailScreen doc={detailDoc} corrections={corrections}
      onSave={(k, v) => { setCorrections({ ...corrections, [k]: v }); say("Saved."); }}
      onOpenViewer={(i) => { setViewer(i); setViewerMode("cleaned"); }}/>;
  } else {
    header = <AppHeader connection={connection}/>;
    tabs = <TabBar active={screen} onSelect={onNavigate}/>;
    if (screen === "capture") content = <CaptureScreen uploads={UPLOADS} pendingPages={pendingPages}
      onAddPage={() => setPendingPages(pendingPages + 1)}
      onUpload={() => { setPendingPages(0); say("2 pages uploading to your server."); }}
      onOpenDoc={() => { onNavigate("archive"); setDetailDoc(DOCS[2]); }}/>;
    else if (screen === "archive") content = <ArchiveScreen state={archiveState} docs={docs}
      query={query} setQuery={setQuery} cat={cat} setCat={setCat}
      onOpen={setDetailDoc} onOpenFilters={() => setShowFilters(true)}
      onRetry={() => say("Still no route to mini.local.")} onGoCapture={() => onNavigate("capture")}/>;
    else content = <SettingsScreen onPair={() => setShowPair(true)} appearance={dark ? "dark" : "light"} setAppearance={() => {}}/>;
  }

  return (
    <div data-theme={dark ? "dark" : undefined} data-screen-label={showDetail ? "Mobile · document detail" : "Mobile · " + screen}
      style={{height:"100%",display:"flex",flexDirection:"column",background:"var(--surface-page)",color:"var(--text-1)",fontFamily:"var(--font-sans)",position:"relative",overflow:"hidden",paddingTop:56,paddingBottom:20,boxSizing:"border-box"}}>
      {header}
      {content}
      {tabs}
      {showFilters ? (
        <div style={{position:"absolute",inset:0,zIndex:40}}>
          <div style={{position:"absolute",inset:0,background:"var(--scrim)"}} onClick={() => setShowFilters(false)}></div>
          <div style={{position:"absolute",left:0,right:0,bottom:0}}>
            <Sheet inline title="Filters">
              <SectionLabel style={{marginTop:0}}>Category</SectionLabel>
              <div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
                {["all","government","medical","insurance","bank","utility","telecom","housing","employment"].map((c) =>
                  <Chip key={c} selected={cat===c} onClick={() => setCat(c)}>{c==="all"?"All":c}</Chip>)}
              </div>
              <SectionLabel>Date range</SectionLabel>
              <div style={{display:"flex",gap:10}}>
                <TextField label="From" value="Jan 2026" onChange={() => {}} style={{flex:1}}/>
                <TextField label="To" value="Jul 2026" onChange={() => {}} style={{flex:1}}/>
              </div>
              <div style={{marginTop:18}}>
                <Button fullWidth onClick={() => setShowFilters(false)}>Show {docs.length} document{docs.length===1?"":"s"}</Button>
              </div>
            </Sheet>
          </div>
        </div>
      ) : null}
      {showPair ? (
        <div style={{position:"absolute",inset:0,zIndex:40}}>
          <div style={{position:"absolute",inset:0,background:"var(--scrim)"}} onClick={() => setShowPair(false)}></div>
          <div style={{position:"absolute",left:0,right:0,bottom:0}}><PairSheet onClose={() => setShowPair(false)}/></div>
        </div>
      ) : null}
      {viewer !== null ? <ImageViewer page={viewer} mode={viewerMode} setMode={setViewerMode} onClose={() => setViewer(null)}/> : null}
      {toast ? (
        <div style={{position:"absolute",left:0,right:0,bottom:76,display:"flex",justifyContent:"center",zIndex:60,pointerEvents:"none"}}>
          <Toast tone="ok">{toast}</Toast>
        </div>
      ) : null}
    </div>
  );
}

/* ── Kit page (chrome + device frame) ───────────────────── */
export function MobileKit() {
  const [dark, setDark] = React.useState(false);
  const [screen, setScreen] = React.useState("capture");
  const [archiveState, setArchiveState] = React.useState("populated");
  const IOSDevice = window.IOSDevice;

  const chip = (active) => ({
    border:"1px solid " + (active ? "var(--accent)" : "var(--border-strong)"),
    background: active ? "var(--accent-tint)" : "var(--surface-card)",
    color: active ? "var(--accent)" : "var(--text-2)",
    borderRadius:"var(--radius-full)",padding:"6px 14px",cursor:"pointer",
    font:"500 var(--text-sm) var(--font-sans)",
  });

  return (
    <div style={{minHeight:"100vh",background:"var(--surface-page)",fontFamily:"var(--font-sans)",display:"flex",flexDirection:"column",alignItems:"center",gap:18,padding:"26px 16px 48px",boxSizing:"border-box"}}>
      <div style={{display:"flex",flexWrap:"wrap",gap:8,justifyContent:"center",alignItems:"center",maxWidth:640}}>
        {[["onboarding","Onboarding"],["capture","Capture"],["archive","Archive"],["settings","Settings"]].map(([id, label]) =>
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
      <IOSDevice dark={dark} width={402} height={874}>
        <MobilePhone dark={dark} screen={screen} archiveState={archiveState} onNavigate={setScreen}/>
      </IOSDevice>
      <div style={{fontFamily:"var(--font-mono)",fontSize:"var(--text-xs)",color:"var(--text-3)"}}>my-flopy · mobile UI kit · tap through: cards → detail, inline edits, sheets</div>
    </div>
  );
}
