# Snail-Mail Archiver — Project Plan

> A fully local, self-hosted system to photograph, read, tag, archive, and search
> physical mail. Capture with a phone, process on your own hardware, and never let a
> single byte leave your network.

- **Owner:** niels@eviloverlord.nl
- **Status:** Executing (v0.3) — Phase 0 spike complete: **GO** (see `docs/phase0/VERDICT.md`); Phase 1–2 build in flight
- **Last updated:** 2026-07-03
- **Working name:** *my-flopy* (rename later, e.g. "Postvault", "Briefkist", "Mailcrate")

## Decision log — 2026-07-03 (v0.2, execution-start reality check)

Confirmed with the owner at execution start; each decision is also annotated inline
in the section it supersedes.

1. **The production host is the owner's existing always-on Mac mini: Apple M1,
   8 GB unified memory, macOS 14.4** — not a to-be-bought 32 GB machine. Every
   sizing decision below follows from this. A RAM upgrade (new mini) remains a
   possible later step and restores the original 8B-model plan.
2. **VLM tier drops to Qwen3-VL-4B (primary) / Qwen3-VL-2B (fallback)** — both
   Apache-2.0, both fit 8 GB. Qwen3-VL-8B does not fit usably. (§6.3)
3. **Bespoke-light backend, not the Paperless-ngx fork, and no Docker on this
   host**: FastAPI + SQLite (FTS5 + sqlite-vec) as native processes. Docker
   Desktop's VM plus the Paperless stack (Postgres/Redis/web) plus a resident
   VLM does not fit in 8 GB; Docker on macOS also has no Metal passthrough.
   Paperless-ngx remains a documented fallback/migration option. (§6.5, §6.6, §6.8)
4. **First capture surface is a mobile web page served by the backend** (phone
   browser camera → upload over LAN/tunnel), because the host has no Xcode and
   the native Flutter/VisionKit app cannot be built here. Flutter app deferred
   to a later phase. (§6.7, roadmap §10)
5. **Phase 0 test data is synthetic-first**: generated NL/DE/EN letters with
   known ground truth, photo-degraded. The owner drops real letter photos into
   a designated folder later; the benchmark re-runs on them for the true
   go/no-go. (§10 Phase 0)

## Decision log — 2026-07-03 (v0.3, Phase 0 spike findings)

Measured on the production host (8 GB M1 mini) against the synthetic set; the
benchmark of record is `docs/phase0/` (see `VERDICT.md` there).

6. **OCR primary = Apple Vision** (macOS Vision framework, on-device, ~zero
   extra resident RAM): 99.9% character accuracy across ALL degradation tiers
   on the synthetic set — at/above the §11 targets. PaddleOCR (PP-OCRv5 latin)
   is benchmarked alongside as the cross-platform alternative; Tesseract
   dropped from consideration for v1. (§6.2)
7. **Extraction is TEXT-FIRST: the VLM reads the OCR transcript; the page
   image is NOT attached by default.** Measured on qwen3-vl:4b-instruct:
   attaching the image *degraded* structured extraction (fields plainly in the
   OCR text returned null) and added ~50 s vision-encode per page. With
   OCR at 99.9%, the transcript is the better eye. Image attachment remains an
   escalation path for low-OCR-confidence documents. This softens the §6.4
   "image + OCR text" formula on 4B-class models. (§6.4)
8. **Model/runtime pins that matter on this host** (§6.3 gotchas, all
   measured, all trap-shaped): use the **`-instruct` Ollama tags** — the bare
   `qwen3-vl:*` tags are *thinking* models that burn their entire constrained-
   decoding budget on reasoning and return empty JSON; keep **`num_ctx` at
   4096** — 8192's KV cache spills out of the ~5.3 GiB Metal budget and
   generation collapses from ~13 tok/s to ~1.4 tok/s; **schema fields must be
   required-but-nullable** — optional fields let the grammar (and the model)
   skip keys that are plainly on the page.
9. **Tags are reconciled deterministically** (§6.4 as designed): the domain
   tag follows doc_type, `bill` follows a validated payment amount, and model
   judgment is trusted only for `legal`/`personal`. Small models fill
   grammar-constrained tag lists with plausible junk otherwise (measured 60%
   precision raw → reconciliation fixes it).

---

## 1. Goal

Build a **desktop + mobile app** that turns a snapshot of a physical letter into a
clean, searchable, auto-tagged archive entry — with **100% local processing**.

The core loop:

1. **Capture** — Take a photo of a letter/envelope with the phone.
2. **Clean** — Auto-detect edges, deskew, dewarp, enhance contrast.
3. **Read** — OCR + a local vision-language model extract the full text.
4. **Understand** — A local model derives structured metadata (sender, recipient,
   date, document type, reference numbers, amounts, due dates) and tags.
5. **Archive** — Store the image, OCR text, and metadata; file it under the right
   correspondent/category.
6. **Search** — Find any document by keyword, tag, sender, date range, or meaning
   (semantic search).

### Non-negotiable constraint: local-first, zero cloud

Every stage — OCR, VLM inference, embeddings, search, storage — runs on hardware you
control (your Mac, a home server, or a NAS). **No third-party API calls, no telemetry,
no cloud OCR.** The mobile app talks only to *your* backend over your LAN/VPN. This is
the single most important design driver and it shapes every technology choice below.

---

## 2. Background & Why Now

Two things changed recently that make this feasible on consumer hardware:

- **Small vision-language models (VLMs) got good.** Qwen2.5-VL and Qwen3-VL (Oct 2025)
  in the 3B–8B range read documents, do layout-aware OCR, *and* extract structured
  fields in one pass — running comfortably on a 16–32 GB Mac or a modest GPU box.
- **Local runtimes matured.** Ollama, llama.cpp (Metal), MLX/mlx-vlm, and vLLM all
  support these models out of the box, so you don't need bespoke ML infrastructure.

This means the "read the letter and understand it" step no longer requires the cloud.

---

## 3. Scope

### In scope (v1)
- Mobile capture (iOS first; the owner is on Apple Silicon / macOS).
- Auto edge-detection, deskew, perspective correction, contrast enhancement.
- Multi-page documents (a letter is often several pages) and envelope + contents.
- Local OCR + VLM metadata extraction, **multilingual: Dutch, English, German** at minimum.
- Structured metadata: correspondent (sender), recipient, document date, received date,
  document type, reference/customer numbers, monetary amounts, due/pay-by dates, IBAN.
- Auto-tagging with a controlled + free-form tag vocabulary.
- Archive storage with original image, cleaned image, OCR text, and metadata.
- Full-text **and** semantic search; filter by tag/correspondent/date/type.
- Desktop app for browsing, correcting, bulk-managing the archive.

### In scope (later / v2+)
- Android capture.
- Import from scanners / PDF / email (`.eml`) so paper *and* digital mail live together.
- Automatic correspondent detection & "file this like the last one from X" learning.
- Reminders for due dates / actionable mail (bills, deadlines).
- Duplicate detection, retention rules ("keep 7 years"), export.
- OCR quality feedback loop (corrections improve future extraction prompts).

### Out of scope
- Any cloud sync, cloud backup, or SaaS component.
- Sharing/collaboration/multi-tenant. This is a single-household personal archive.
- Paying bills or acting on mail automatically (surface reminders only).

---

## 4. Users & Key Scenarios

Single primary user (the owner), possibly a household (2–3 people, shared archive).

- *"I just got a letter from the tax office — snap it, and later find it by searching
  'belasting 2026'."*
- *"Show me every bill with a due date in the next 30 days."*
- *"Find that insurance policy — I don't remember the sender, but it mentioned a red car."*
  (semantic search)
- *"How much did I pay the dentist last year?"* (filter by correspondent + amounts)

---

## 5. Architecture Overview

A **thin mobile client + a self-hosted backend** on the owner's hardware. Heavy ML runs
on the backend (a Mac or home server), not the phone — phones lack the RAM for good VLMs
and it keeps the models in one place.

*(diagram amended 2026-07-03 to the as-built v1: web app instead of Flutter, SQLite
instead of Postgres, everything native on the 8 GB mini — see the decision log)*

```
┌─────────────────────────┐         LAN / Tailscale VPN         ┌────────────────────────────────────┐
│   Phone (web app)       │  ───────  HTTPS (token)  ─────────► │  Self-hosted Backend (Mac mini,    │
│  mobile capture page    │                                     │  all native processes, no Docker)  │
│  • Browser camera       │                                     │                                    │
│  • Upload queue         │  ◄────  status / results  ────────  │  API (FastAPI)                     │
│  • Status view          │                                     │    │                               │
└─────────────────────────┘                                     │    ├─ Ingest & preprocess (OpenCV) │
                                                                │    ├─ OCR (Apple Vision /          │
┌─────────────────────────┐                                     │    │     PaddleOCR — Phase 0 pick) │
│  Desktop (same web app) │  ───────  same local API  ────────► │    ├─ VLM extract (Qwen3-VL-4B     │
│  • Browse / search      │                                     │    │     via Ollama, native)       │
│  • Correct metadata     │                                     │    ├─ Embeddings (bge-m3)          │
│  • Bulk manage          │                                     │    └─ Tagging / classification     │
└─────────────────────────┘                                     │  Storage:                          │
                                                                │    • Files on disk (originals)     │
   (Flutter native apps: deferred — §6.7)                       │    • SQLite (metadata + FTS5       │
                                                                │        + sqlite-vec)               │
                                                                └────────────────────────────────────┘
```

**Processing is async and queued.** Capture is instant; the phone uploads and the
backend processes in the background (OCR + VLM can take a few seconds per page). The
user gets a notification / updated status when a document is filed. This keeps the
capture experience snappy and decouples it from model latency.

**Remote access** (using the app away from home) is solved with a private overlay
network — **Tailscale/WireGuard** — not by exposing anything to the public internet.
The backend is never internet-reachable. This is detailed in §5.1.

---

## 5.1 Remote Access & Leak-Hardening ("on the road")

**Goal:** use the app anywhere, while keeping the "nothing leaves my hardware" guarantee
intact. The resolution is that *"on the road" is a networking problem, not a hosting one*
— the server stays on hardware you own; your phone reaches it through a private encrypted
tunnel, so documents only ever travel device-to-device between things you control. From
the public internet, the server does not exist.

### Where to host — home box vs. rented VPS

| | **Home server + tunnel (recommended)** | **Rented VPS** |
|---|---|---|
| Where documents live | Your disk, your house | A provider's disk in a datacenter |
| "Nothing leaves my servers" | ✅ Holds truly | ⚠️ Weakened — provider *could* reach disk/RAM |
| Cost | One-time hardware | Monthly, forever |
| VLM-capable hardware | You control (Mac mini / GPU box) | GPU VPS is expensive |
| When to choose | This project's no-leak goal | Only if you genuinely can't host at home |

**Recommendation:** host at home and tunnel in. A VPS re-introduces exactly the
third-party-in-the-data-path risk the project exists to avoid. If a home server is truly
impossible, use a VPS *only* with full-disk encryption where you alone hold the key, and
accept the reduced guarantee explicitly.

**Decided hardware: an always-on Apple Silicon Mac mini** — it is both the VLM host and
the always-on server. ~~Target **32 GB** unified memory (comfortably runs a 7–8B VLM plus
Postgres/search with headroom; 16 GB works but is tight).~~ **Superseded 2026-07-03:**
the actual host is the owner's existing **M1 mini with 8 GB** (also runs Plex/Sonarr/etc.).
Consequences: 4B-class VLM (§6.3), SQLite instead of Postgres, no Docker, sequential
pipeline stages to cap peak RAM. A 32 GB replacement remains the upgrade path back to
8B-class models. MLX gives the best Apple-Silicon throughput.

**Mac-mini-specific setup notes (these shape the architecture):**
- **The VLM runs natively on macOS, not in Docker.** Docker Desktop on Mac runs Linux
  containers in a VM with **no Metal GPU passthrough**, so Ollama/MLX must run as a
  **native host process** to use the GPU. ~~Practical split: Ollama native on the host;
  API, workers, Postgres, and search in Docker Compose.~~ **Superseded 2026-07-03:**
  on the 8 GB host there is no Docker at all — **every component (API, worker, Ollama,
  SQLite) is a native macOS process** (§6.6, decision log #3).
- **Egress lockdown is therefore entirely host-level.** All processing runs natively,
  so the anti-leak control is a macOS **application firewall that blocks outbound
  per-process** (built-in pf via a ruleset, or **LuLu**/Little Snitch): deny the
  Ollama, worker, and OCR processes any outbound network access; allow the API process
  to answer only on the tunnel interface. ~~Container network isolation covers the
  Dockerized services~~ — nothing runs in containers; the container-isolation notes
  below apply only if containers return with bigger hardware.
- **Always-on:** disable sleep for the server role (`sudo pmset -a sleep 0 disksleep 0`;
  set "Start up automatically after a power failure"). Note the tension with FileVault:
  FileVault requires a password at boot, so after a power outage the box won't auto-unlock
  headless. Options: accept a manual unlock after outages (most secure), or evaluate the
  tradeoffs of an automated-unlock setup. Decide this in Phase 3 hardening.
- Reach the mini headless over the tunnel (SSH / Screen Sharing over Tailscale) — never
  expose those to the internet.

### Threat model → control (defense in depth)

The overlay makes the network safe; that shifts the weak links to **the phone** and
**the models/dependencies**. Harden every layer:

| Threat | Control |
|---|---|
| Interception on public WiFi | WireGuard end-to-end encryption; no plaintext ever on the wire |
| Server found/exploited from the internet | **No port forwarding, no public ports.** Bind the API to the tunnel interface, never `0.0.0.0`. The box is unreachable except over the tunnel |
| **A model/dependency exfiltrates documents** | **Egress lockdown — the key anti-leak control.** Deny the OCR/VLM/worker **processes** all outbound network access via the host application firewall (pf ruleset or LuLu — host-level because everything runs natively, see setup notes above); once models are pulled they never need the internet, so a compromised model *physically cannot* phone home. Deny-all outbound on the host; allowlist nothing |
| Foothold on the tunnel still hits the API | Layer app auth on top of device identity: per-device **token or mTLS**, revocable; auth on every endpoint |
| Lost/stolen phone | Device biometric/passcode; cache **thumbnails, not originals**; drop full images after upload is confirmed; **remotely revoke** the phone's tunnel key + app token |
| Stolen server disk | Full-disk encryption (FileVault/LUKS) **+** app-level encryption of document blobs, so a powered-off disk yields nothing |
| Backup leak | Encrypted backups (restic/age) with a key only you hold |

### Overlay choice
- **Tailscale** (WireGuard-based) — easiest: NAT traversal, device ACLs, MagicDNS, key
  rotation. Its coordination server handles only key exchange/coordination — **traffic is
  end-to-end encrypted device-to-device and never passes through Tailscale**.
- **Headscale** (self-hosted Tailscale control server) or **plain WireGuard** — if you
  want zero third-party coordination at all. More setup, maximal control.

### Hardening checklist (build-time)
- API bound to the tunnel interface only; host firewall default-deny inbound *and* outbound.
- Model/worker processes: per-process outbound deny (pf/LuLu), least-privilege user.
  *(If containers ever return on bigger hardware: no network, read-only rootfs,
  dropped Linux capabilities as well.)*
- Request size limits, rate limiting, no directory listing, audit log of every access.
- Per-device credentials, short-lived tokens, one-click revocation of a device.
- Airplane-mode / egress-block test in CI-equivalent: prove the stack works with zero
  outbound connectivity (this is also KPI §11-privacy).

---

## 6. Technology Decisions

Each choice below lists the recommendation, the runner-up, and the reasoning. Grounded
in current (2025–2026) tooling.

### 6.1 Image capture & preprocessing (on device + backend)
- **Recommendation:** On-device document scanning UI + edge detection at capture time,
  then a robust backend cleanup pass.
  - **iOS capture *(deferred with the Flutter app, §6.7 — v1 uses the browser camera
    + backend cleanup)*:** `VNDocumentCameraViewController` (Apple VisionKit) gives
    Apple-quality edge detection, multi-page capture, and perspective correction *for
    free*, fully on-device. Wrap it via a Flutter platform channel or the
    `cunning_document_scanner` plugin.
  - **Android (later):** ML Kit Document Scanner (on-device) or `jscanify`/OpenCV.
  - **Backend cleanup:** OpenCV for deskew, dewarp, adaptive thresholding, and
    denoising as a normalization pass before OCR (handles cases the phone missed).
- **Why:** Preprocessing quality is the single biggest lever on OCR accuracy for
  *photographed* (not flatbed-scanned) documents. The native OS scanners (VisionKit /
  ML Kit) already do auto-detect, crop, perspective correction, deskew, and enhancement
  on-device with an Apple-Notes-quality UI — wrap them via **one Flutter plugin** (e.g.
  `cunning_document_scanner`) rather than rebuilding capture UX. Doing a first pass
  on-device and a second on the backend is belt-and-suspenders and all local.
- **Deferred:** ML *dewarping* of curved pages (DocTr/GeoTr family). Snail mail is mostly
  flat sheets, and the best dewarp models carry **research-only / non-commercial licenses**
  and need a GPU — so they'd break the fully-local, freely-licensed goal. Out of v1.

### 6.2 OCR engine
- *(Amended 2026-07-03: given the Apple Silicon host, **Apple Vision OCR and PaddleOCR
  are benchmarked head-to-head in Phase 0 and the winner becomes primary** — Apple
  Vision costs ~zero extra RAM, which matters on 8 GB. The text below stands as the
  candidate list.)*
- ***Benchmark outcome (decision log #6): Apple Vision is primary** — 99.9% char
  accuracy on every tier of the synthetic set (`docs/phase0/`). PaddleOCR stays the
  cross-platform alternate (note: paddlex phones home on init unless
  `PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True` — an egress trap, disabled in our
  engine wrapper; models pre-download once at install).*
- **Recommendation:** **PaddleOCR (PP-OCRv5)** as the primary OCR engine, with
  **Surya** as a strong alternative and **Tesseract 5** as a battle-tested fallback.
  - **PaddleOCR** — best accuracy/speed balance on real-world photos, excellent
    multilingual (Latin scripts incl. NL/DE/EN), good on skewed/low-quality input,
    Apache-2.0.
  - **Surya** — modern, very strong layout + reading-order detection and multilingual
    OCR; great for structured documents. Check license terms for your use (research/
    personal use is fine).
  - **Tesseract 5** — LSTM-based, rock-solid, trivial to self-host, weaker on messy
    photos but a safe fallback. This is what Paperless-ngx uses.
  - **Apple Vision OCR** — genuinely excellent and free on Apple Silicon; viable if the
    backend is a Mac. Worth benchmarking as a primary option given the owner's hardware.
- **Why not VLM-only for OCR?** VLMs are great at *understanding* but can hallucinate
  exact strings (IBANs, reference numbers, amounts). A dedicated OCR engine gives a
  verbatim text layer you can trust and index; the VLM then reasons over image + OCR
  text together. Belt-and-suspenders again.

### 6.3 Vision-language model (understanding & extraction)
- **Recommendation *(amended 2026-07-03 for the 8 GB host)*:** **Qwen3-VL-4B** as the
  primary extractor, **Qwen3-VL-2B** as the low-RAM fallback (both Apache-2.0). The
  original pick, **Qwen3-VL-8B**, needs ~6–9 GB for weights alone and does not fit
  usably in 8 GB total; it becomes the upgrade path if the host RAM grows. Quantize to
  **Q4_K_M** (the accepted sweet spot; the vision projector stays FP16 even in Q4
  builds, so vision loss is small — avoid aggressive GPTQ).
  - Runs locally via **Ollama** (easiest), **MLX/mlx-vlm** (fastest on Apple Silicon,
    ~15–25% quicker than llama.cpp), **vLLM** (best server throughput + reliable
    schema-guided JSON), or **llama.cpp** (most flexible).
  - **Memory (Apple Silicon unified RAM / GPU VRAM), Q4:** 3–4B ≈ 3 GB, 7–8B ≈ 6–9 GB,
    32B ≈ 21 GB. A **16 GB** Mac runs the 7–8B comfortably; **32 GB** runs 32B-class
    models if you want more accuracy.
- **⚠️ Licensing matters here, and you are EU-domiciled (`.nl`) — this is decision-changing:**
  - **Qwen3-VL** — **Apache-2.0 on every size** (2B → 235B). Cleanest option, no MAU
    cap, no EU carve-out. This is *why* it's the primary pick.
  - **Qwen2.5-VL** — mixed: **7B and 32B are Apache-2.0** (use these); the **3B is
    "Qwen Research" — non-commercial only** (avoid — easy trap since its siblings are
    open); 72B has a 100M-MAU clause.
  - **AVOID Llama 3.2 Vision (11B/90B):** its license explicitly does **not** grant the
    vision weights to parties domiciled in the EU — a hard blocker for you — and it's
    also the weakest of the field at dense OCR. Do not use it.
  - **EU-clean non-Chinese alternatives** if you want them: **InternVL3.5-8B**
    (Apache-2.0, best on vLLM/LMDeploy), **Gemma 3 12B** (multilingual, wide tooling),
    **Pixtral 12B** (Apache-2.0, OCR-oriented). **MiniCPM-V 4.5** has excellent
    OCR-per-GB but its weights need a registration questionnaire (fine for personal use).
  - **Moondream 2** (Apache-2.0, ~1.9B) is a viable ultra-light option for clean print.
- **Version floors (important):** Qwen2.5-VL needs **Ollama ≥ 0.7.0** / **vLLM > 0.7.2**;
  Qwen3-VL needs **Ollama ≥ 0.12.7** / **vLLM ≥ 0.11.0** (llama.cpp GGUF vision now
  merged; Qwen ships official GGUFs). On MLX use **mlx-vlm ≥ 0.3.x**.
- **OCR-specialist option:** if pure character accuracy becomes the bottleneck, a
  dedicated model — **dots.ocr** (MIT), **Nanonets-OCR2-3B** (Apache-2.0, Ollama-ready),
  or **PaddleOCR-VL 0.9B** (Apache-2.0) — can beat a general VLM, at the cost of Qwen's
  flexible free-form field reasoning. Consider as a two-stage upgrade, not for v1.
- **Gotchas measured on our own host (decision log #8):** use the `-instruct`
  Ollama tags (bare `qwen3-vl:*` = thinking variant → empty JSON under
  constrained decoding); `num_ctx` 4096, not more (KV spill past the ~5.3 GiB
  Metal budget → ~10× slower generation); schema fields required-but-nullable.
- **Known gotchas to design around:**
  - llama.cpp uses a **two-file** scheme (main GGUF + separate `mmproj` vision
    projector) — a missing/mismatched `mmproj` silently breaks vision or emits garbage
    (strings of `@`). Use a **FP16 mmproj** on CUDA.
  - There is an open `llama-server` fine-grained-OCR accuracy regression (build b8545+);
    for exact-string reading prefer `llama-cli`, MLX, or Ollama, and **rely on the
    dedicated OCR layer for verbatim fields** rather than the VLM.
  - Qwen3-VL on Ollama was cloud-first at launch and had early Metal image-crash bugs —
    pin to a known-good version and test image input end-to-end before committing.
- **Why Qwen-VL:** best open, permissively-usable document VLM family for local use in
  this size class, with the most complete runtime coverage (Ollama/llama.cpp/MLX/vLLM).

### 6.4 Metadata extraction & tagging strategy
- **Recommendation:** A **two-stage, schema-constrained** pipeline:
  1. **OCR** produces verbatim text (trusted for exact strings).
  2. **VLM/LLM** receives ~~*image + OCR text*~~ **the OCR text (text-first —
     amended by decision log #7: on 4B-class models the image input measurably
     degraded extraction and tripled latency; image attachment is the escalation
     path for low-OCR-confidence documents, not the default)** and returns
     **strict JSON** matching a
     predefined schema. **JSON format reliability is a decoding-layer problem, not a
     model-choice problem** — enforce it, don't just prompt for it. Concretely: define
     the schema as a **Pydantic** model → pass its JSON Schema to **Ollama structured
     outputs** (`format=<schema>`, not merely `format="json"`) or **vLLM `guided_json`**
     / **llama.cpp GBNF grammar** → validate with Pydantic → retry on failure. With
     constrained decoding even a 3B model emits 100%-schema-valid JSON; without it,
     expect stray markdown fences and prose leakage. **Structural validity ≠ correct
     values** — always validate field contents downstream (next step).
  - Post-validate extracted fields with **deterministic parsers/regex** (IBAN checksum,
    date normalization, amount/currency, postal codes) — never trust the model on
    format-critical fields.
  - **Tagging:** hybrid — (a) a controlled vocabulary the model must map into
    (e.g. `bill`, `insurance`, `government`, `bank`, `medical`, `subscription`,
    `legal`, `personal`), plus (b) up to N free-form tags; then reconcile free-form
    tags against existing ones to avoid tag sprawl.
- **Text-only LLM option** (if not letting the VLM tag directly): small local models via
  Ollama — **Qwen2.5-7B**, **Llama 3.2 3B**, **Phi-4**, **Gemma 2** — all do reliable
  JSON extraction from OCR text with schema constraints.

### 6.5 Search layer
At this scale (thousands of docs) everything is fast enough; the real constraints are
**operational simplicity** and **multilingual embedding quality**. Two good paths:
- **If bespoke backend *(chosen 2026-07-03, see §6.8)*:** **SQLite FTS5 + sqlite-vec**
  fused with **Reciprocal Rank Fusion (RRF)**. Zero extra services, one file to back
  up — the simplest thing that fully works, and the only thing that fits comfortably
  next to a resident VLM in 8 GB. (Pin sqlite-vec; it's still pre-v1.)
- **If forking Paperless-ngx (~~recommended~~ superseded, see §6.8):** it already ships **PostgreSQL +
  full-text search**, so use **Postgres FTS + pgvector** and don't add a second
  datastore. Meilisearch (MIT) is the "batteries-included hybrid, least code" option if
  you'd rather not hand-roll RRF.
- **Skip** Qdrant/Typesense — overkill at this scale.
- **Embeddings model (local, multilingual NL/DE/EN):** **bge-m3** (MIT, 1024-dim, strong
  on all three languages) via Ollama — top pick. Alternatives: nomic-embed-text-v2-moe
  or EmbeddingGemma-300M if you want smaller. **Avoid** nomic-v1.5 / all-MiniLM
  (English-centric).
- **Why:** keyword + semantic search in one store, minimal ops, and embedding quality
  that actually holds up in Dutch and German.

### 6.6 Backend
- **Recommendation *(amended 2026-07-03)*:** **Python + FastAPI** for the API, with a
  **SQLite-backed job queue processed by an in-process/native worker** for async
  processing. ~~Celery/Redis … and Docker Compose to run the whole stack~~ —
  **superseded:** on the real 8 GB host there is no Docker at all; every component
  (API, worker, Ollama, SQLite) runs as a **native macOS process**. Docker Desktop's
  Linux VM would burn ~1–2 GB of the 8 GB for zero benefit, and Docker on Mac has no
  Metal passthrough anyway. Celery/Redis is overkill for a single-household queue.
- **Why Python:** the entire local-ML ecosystem (PaddleOCR, Surya, OpenCV, mlx-vlm,
  embeddings) is Python-native. FastAPI is ergonomic and fast.
- **Backend is the Mac mini (decided):** everything native. The egress lockdown in
  §5.1 is therefore entirely **host-level** (pf/LuLu per-process rules) — the
  container-level isolation described there applies only if containers return with
  bigger hardware.

### 6.7 Cross-platform app framework (desktop + mobile, one codebase)
- **Amended 2026-07-03 — v1 ships a web UI, Flutter is deferred.** The host has no
  Xcode (and 8 GB makes local iOS toolchains painful), so the native Flutter/VisionKit
  app can't be built on it today. v1 instead serves a **mobile-first web app from the
  backend**: iPhone Safari's `<input capture>` / `getUserMedia` camera for capture +
  upload over the LAN/tunnel, and the same app as the desktop browse/search/correct
  surface. This loses VisionKit's native edge-detection UX — compensated by the
  backend OpenCV cleanup pass — and gains zero-install, zero-signing deployment.
  The Flutter plan below stands as the *later* native-app path (needs Xcode, any Mac).
- **Original recommendation (deferred, not dropped):** **Flutter**.
  - One codebase for **iOS, Android, macOS, Windows, Linux** — genuinely covers the
    desktop + mobile requirement.
  - Mature camera + platform-channel access (needed to call VisionKit's document
    scanner on iOS), good offline/local-network HTTP, solid list/search UIs.
  - **Runner-up:** **Tauri v2** (Rust) — excellent desktop, and mobile support has
    matured, but its mobile story and camera/scanner plugin ecosystem are less proven
    than Flutter's. Consider if you strongly prefer a web-tech frontend.
  - **Also viable:** Capacitor + a web UI (fast to build, one PWA-ish codebase) if you
    want to prototype the UI quickly and treat desktop as "a browser tab".
- **Why Flutter:** best single-codebase coverage of *both* first-class mobile capture
  *and* real desktop apps, which is exactly this project's shape.

### 6.8 Build vs. fork an existing project
- **Decided 2026-07-03: the bespoke-light path.** The fork-Paperless recommendation
  below assumed a 32 GB host running Docker. On the real 8 GB mini, Paperless-ngx's
  stack (Postgres + Redis + web + consumer, under a Docker VM) cannot coexist with a
  resident VLM — so v1 is the **bespoke FastAPI + SQLite backend** (§6.5/§6.6), which
  natively fits. Paperless-ngx remains the documented **fallback/migration target** if
  the hardware grows or the bespoke archive proves limiting; its data model still
  informs ours (§8), which keeps a later migration straightforward.
- **Original recommendation (superseded):** **Fork/extend Paperless-ngx** as the archive/search/storage core
  and add the two things it lacks — a great **mobile-photo capture flow** and
  **VLM-based auto-metadata/tagging** — rather than building the whole archive from
  scratch.
  - **Paperless-ngx** (GPL-3.0) — the gold standard for self-hosted document management:
    tags, correspondents, document types, full-text search (Tesseract/OCRmyPDF +
    PostgreSQL + search index), rule/fuzzy matching, a scikit-learn auto-classifier,
    and — critically — **native local-LLM tagging** (Ollama / OpenAI-compatible + FAISS
    RAG) added on top. Clean REST API (`POST /api/documents/post_document/`) purpose-made
    for a custom capture client. Two MIT add-ons compose cleanly: **paperless-ai** and
    **paperless-gpt** (notable for **LLM-vision OCR** — valuable exactly where Tesseract
    struggles on photographed mail). Its data model is almost exactly this project's.
  - **License note:** your separate mobile/desktop app talking to the GPL-3.0 server over
    HTTP is **not** a derivative work, so you can license your app freely. **Avoid the
    AGPL bases** (Papra, Docspell) if you might ever offer this as a hosted service.
  - **Papra** — newer, lighter, cleaner UI; good if you want a smaller codebase to
    extend but fewer batteries included.
  - **Docspell / Mayan EDMS / Teedy** — capable but heavier/older stacks; more to learn,
    less aligned with the mobile-first + VLM workflow.
- **Two-track decision:**
  - **Fast path (recommended to start):** Flutter capture app → Paperless-ngx REST API
    for storage/search, with a **custom pre-processing microservice** (OpenCV + PaddleOCR
    + Qwen-VL) that generates rich metadata/tags and pushes documents in via the API
    (Paperless "consume" folder or API upload + post-processing). You get a proven
    archive on day one and focus your effort on capture + AI.
  - **Bespoke path:** the full custom FastAPI backend from §6.6 if Paperless's model or
    tagging proves too limiting. Keep this as the fallback, not the default.
- **Why:** Paperless-ngx solves ~70% of this project (archive, tags, correspondents,
  search, API, retention) as mature open-source. The *novel* value here is
  **phone-photo capture + local-VLM auto-understanding**, which is where the build effort
  should concentrate.

---

## 7. Recommended Stack (Bottom Line)

*(table amended 2026-07-03 to the as-built v1 stack; original choices that were
superseded are noted inline)*

| Layer | Choice | Notes |
|---|---|---|
| **App (v1)** | **Mobile-first web app served by the backend** (Flutter native app deferred — §6.7) | phone Safari camera capture + desktop browse in one UI, zero install |
| **On-device capture (later, native app)** | VisionKit `VNDocumentCameraViewController` (iOS), ML Kit (Android) | when the Flutter app lands; v1 relies on backend cleanup |
| **Backend API** | **FastAPI** (Python) + SQLite-backed async worker | all native processes, no Docker (§6.6) |
| **Preprocessing** | **OpenCV** | deskew, dewarp, threshold, denoise |
| **OCR** | **Apple Vision + PaddleOCR benchmarked in Phase 0**; Tesseract fallback | verbatim, multilingual NL/DE/EN; winner becomes primary |
| **Understanding/extraction** | **Qwen3-VL-4B** (Apache-2.0; 2B fallback, 8B on future RAM upgrade) via **Ollama** | image + OCR text → schema-constrained JSON |
| **Text LLM (optional)** | small Qwen3 (Apache-2.0), Phi-4-mini (MIT) via Ollama | **not** Llama Vision (EU license) |
| **Embeddings** | **bge-m3** (MIT) via Ollama | multilingual NL/DE/EN semantic search |
| **Datastore** | **SQLite FTS5 + sqlite-vec** (bespoke path — decided §6.8) | one file: metadata + keyword + vector |
| **Archive core** | bespoke (Paperless-ngx = fallback/migration option) | §6.8 |
| **Remote access** | **Tailscale / WireGuard** | private overlay, nothing public |
| **Hardware** | **The owner's existing always-on M1 Mac mini, 8 GB** (upgrade path: 32 GB mini → 8B models) | VLM runs here (native, not the phone); doubles as always-on server — §5.1 |

**Privacy guarantee by construction:** the phone talks only to your backend over a
private network; all models and data live on your hardware; no component makes an
outbound internet request in normal operation.

---

## 8. Data Model (initial sketch)

- **Document**: id, title, correspondent_id, document_type, document_date, received_date,
  language, page_count, source (photo/scan/import), status, created_at.
- **Page**: id, document_id, page_no, original_image_path, cleaned_image_path,
  ocr_text, ocr_confidence, ocr_engine, thumbnail_path.
- **Correspondent**: id, name, aliases, address, default_tags.
- **Tag**: id, name, kind (`controlled` | `free`), color.
- **DocumentTag**: document_id, tag_id, source (`model` | `user`), confidence.
- **ExtractedField**: document_id, key (e.g. `iban`, `amount_due`, `due_date`,
  `reference`), value, normalized_value, confidence, verified (bool).
- **Embedding**: document_id, vector, model, created_at.
- **Audit/Correction**: what the model produced vs. what the user changed (feeds §12).

---

## 9. Processing Pipeline (per capture)

1. **Ingest** — receive image(s) + client metadata (timestamp, GPS optional/off).
2. **Preprocess** — OpenCV: detect page, deskew, dewarp, enhance, split multi-page.
3. **OCR** — PaddleOCR → verbatim text + word boxes + confidence; detect language.
4. **Understand** — Qwen-VL(image + OCR text) → strict-JSON: type, sender, recipient,
   dates, amounts, references, summary, suggested tags.
5. **Validate & normalize** — regex/checksum for IBAN, dates, amounts, postcodes;
   reconcile suggested tags against existing vocabulary; resolve correspondent.
6. **Embed** — bge-m3 over OCR text (+ summary) → vector for semantic search.
7. **Persist** — store images, text, metadata, tags, embedding; index for FTS.
8. **Notify** — push status to the client; flag low-confidence docs for user review.

Every stage logs confidence; anything below threshold routes to a **review queue**
instead of silently guessing.

---

## 10. Roadmap (phased)

### Phase 0 — Spike / feasibility (prove the hard part)
*(amended 2026-07-03: model tier + synthetic-first data, per the decision log)*
- Stand up **Ollama (native) + Qwen3-VL-4B (2B fallback) + OCR (Apple Vision vs
  PaddleOCR benchmark)** on the **Mac mini (the existing 8 GB M1)**.
- Feed 20–30 letters (NL/DE/EN) through a script — **synthetic-first**: generated
  letters with known ground truth, photo-degraded (skew/shadow/blur). The owner drops
  photos of real mail into a designated folder when available and the same benchmark
  re-runs on them for the definitive numbers.
- Measure OCR accuracy and JSON-extraction quality.
- **Airplane-mode smoke test:** cut the mini's internet (or block egress) and confirm
  the pipeline still OCRs + extracts end to end — proving no step depends on the cloud.
- **Peak-RAM measurement:** record peak memory of the full pipeline (Ollama + OCR +
  worker) on the 8 GB host alongside Plex/Sonarr — the fit is plausible but must be
  proven, not assumed.
- **Go/no-go gate** = accuracy targets met *and* airplane-mode test passes *and*
  the pipeline runs within the host's real memory headroom.

### Phase 1 — End-to-end thin slice
*(amended 2026-07-03: web capture + SQLite, per the decision log)*
- **Mobile web capture page** (phone browser camera) → upload to FastAPI → run
  pipeline → store in **SQLite archive** → view result in the desktop web UI.
  *(Originally: Flutter iOS capture → Paperless-ngx/Postgres — deferred/superseded.)*
- One document type end to end; manual correction UI.
- **Camera secure-context note:** iPhone Safari only grants `getUserMedia` on HTTPS.
  v1 capture therefore uses `<input type="file" capture>` (a file-picker-to-camera
  hop, no secure context needed); a live in-page camera UX requires an HTTPS cert on
  the tunnel (`tailscale cert` / local CA) — do that in Phase 3 hardening.

### Phase 2 — Understanding & search
- Full metadata schema + validation, hybrid tagging, correspondent resolution.
- FTS + semantic search (SQLite FTS5 + sqlite-vec + bge-m3) with a real search UI.
- Review queue for low-confidence documents.

### Phase 3 — Polish & daily-driver
- Multi-page robustness, duplicate detection, bulk edit, retention rules.
- Push notifications, offline capture queue, reminders for due dates.
- Backup/restore; **Tailscale remote access + full leak-hardening (§5.1)**: host-level
  egress lockdown on the native VLM process, no public ports, per-device tokens/mTLS,
  FileVault + at-rest blob encryption, phone thumbnail-only caching + remote revocation.
- **Airplane-mode acceptance test (formal):** run the *entire* stack — capture → upload
  over the tunnel → process → store → search — with the Mac mini's outbound network
  blocked, and confirm zero outbound connection attempts (verified by firewall/egress
  monitoring). This is the pass/fail gate for the privacy KPI in §11.

### Phase 4 — Breadth
- Android capture, PDF/`.eml`/scanner import, learning from corrections,
  optional larger VLM for tricky documents.

---

## 11. Goals & Measurables (KPIs)

Concrete, testable targets. Establish a labeled test set of ~100 real documents
(NL/DE/EN mix) early and measure against it every phase.

### Accuracy
- **OCR character accuracy ≥ 98%** on well-lit captures; **≥ 95%** on average phone photos.
- **Correct document type** classification **≥ 95%**.
- **Sender/correspondent correct ≥ 90%** (exact or alias match).
- **Document date correct ≥ 95%**; **amount/IBAN/reference exact-match ≥ 98%** on
  documents where the field is present (format-critical fields must be near-perfect via
  deterministic validation).
- **Auto-tags:** ≥ 90% precision on the controlled vocabulary; ≤ 10% of documents need
  tag correction.
- **Search:** top-5 recall ≥ 95% for keyword queries; ≥ 85% for semantic ("about X")
  queries on the test set.

### Performance
- **Capture-to-uploaded ≤ 3 s** perceived on the phone (async processing after).
- **Full pipeline ≤ 15 s per page** on the target hardware (the 8 GB M1 mini, 4B-class VLM).
- **Search results ≤ 300 ms** for keyword; ≤ 1 s for semantic.

### Effort / UX
- **≤ 2 taps** from open-app to captured document.
- **≥ 80% of documents filed with zero manual correction** (the "just works" rate) by Phase 3.
- **Median time to file one document ≤ 20 s** including capture.

### Privacy (pass/fail, must all hold)
- **Zero outbound internet requests** from any component during capture/processing
  (verified by network monitoring / firewall egress block).
- **All models present and runnable offline** (airplane-mode test passes end to end).
- **All data at rest on owner-controlled storage**, encrypted backups, no third-party
  service in the data path.

### Reliability / adoption
- Process **≥ 500 documents** without data loss during a 1-month dogfood.
- **Backlog cleared:** the owner actually archives their real mail with it for 30 days
  straight (the true success metric).

---

## 12. Continuous Improvement Loop

Every user correction (wrong tag, wrong sender, fixed amount) is logged as
model-output-vs-truth. Use it to (a) refine extraction prompts, (b) grow the
correspondent/tag vocabulary, and (c) build an evaluation set that measures whether
model or prompt changes actually improve real-world results — all locally.

---

## 13. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| VLM hallucinates exact strings (IBAN, amounts) | Wrong financial data | Trust OCR layer + deterministic validation for format-critical fields; never the VLM alone |
| Photographed docs are skewed/low-light | OCR errors | Strong on-device + backend preprocessing; capture UX nudges (guides, retake) |
| Local runtime bugs (Qwen3-VL Metal crash, llama-server OCR regression) | Broken vision / silent accuracy loss | Pin known-good versions; prefer Ollama/MLX; test image path end to end before upgrading |
| Model too big for hardware | Slow / won't run | Start at 4B Q4 (fits the 8 GB host — decision log #2); scale up only if hardware grows |
| Multilingual accuracy (NL/DE) | Wrong extraction | Choose multilingual OCR (PaddleOCR/Surya) + bge-m3 embeddings; test set covers all three languages |
| **Model license unusable in EU** | Legal blocker / rework | Stick to Apache-2.0 weights (Qwen3-VL, InternVL3.5, Pixtral) or Gemma terms; **never Llama Vision** (not licensed to EU parties); avoid Qwen2.5-VL-3B (research-only) |
| Scope creep (build everything from scratch) | Never ships | Bespoke-*light* only (FastAPI + SQLite, decision log #3): mirror Paperless's data model for a later migration; concentrate effort on capture + AI |
| Remote access ("on the road") exposes the backend | Document leak | Private overlay only, no public ports, host-level egress lock on model/worker processes, per-device token/mTLS — full design in **§5.1** |
| Lost/stolen phone (the weak link once network is safe) | Cached documents leak | Thumbnails-not-originals caching, device lock, remote key/token revocation (§5.1) |
| Backup/data loss | Lose the archive | Automated encrypted local/off-site-you-control backups from day one |

---

## 14. Open Questions

- ~~**Backend hardware:** dedicate the Mac, or build a Linux+GPU box?~~ **Decided
  (updated 2026-07-03):** the owner's existing always-on **M1 Mac mini, 8 GB** — VLM
  native via Ollama, 4B-class models; 32 GB mini is the future upgrade path — see §5.1.
- ~~**Fork vs. bespoke:** commit to Paperless-ngx as the core, or keep the option open
  through Phase 1 and decide at the Phase 2 gate?~~ **Decided 2026-07-03:**
  bespoke-light (FastAPI + SQLite); Paperless-ngx demoted to fallback/migration
  option — it doesn't fit the 8 GB host. See §6.8.
- **Household use:** single user, or shared archive for 2–3 people (affects auth &
  correspondent model)?
- **iOS distribution** *(deferred with the Flutter app, §6.7 — v1's web app needs no
  distribution)*: personal dev build / TestFlight / self-signed — how will the app
  get onto the phone(s)?
- **Retention & legal:** which document classes need guaranteed retention periods
  (tax = 7 years in NL), and should the app enforce them?

---

## 15. Prior Art & Competitive Landscape

Researched 2026-07-03. **Verdict: no single existing product does exactly this.**
Nothing on the market combines all of this project's defining traits — a
mail-tailored phone-photo capture UX, **local-VLM structured extraction** of
mail-native fields (correspondent, IBAN, amounts, due dates, references), and a
**local-first archive with both full-text AND semantic search** — in one
purpose-built, single-household product. The closest reality is exactly what §6.8
already anticipates: **assemble Paperless-ngx + an AI plugin + a third-party
mobile app yourself**, an assembly that still leaves real gaps.

### Closest existing solutions

- **Paperless-ngx + paperless-gpt + Swift Paperless** (the assemble-it-yourself
  stack) — the real competitor and the basis for our fork/fallback thinking.
  - [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) — self-hosted
    archive core: Tesseract OCR, full-text search, tags/correspondents/types/custom
    fields. No semantic/vector search.
  - [paperless-gpt](https://github.com/icereed/paperless-gpt) — LLM layer with
    **local Ollama vision OCR** and metadata (title, tags, correspondent, date,
    custom fields). But **no first-class IBAN / amount / due-date extraction**, and
    it does not encode the §6.4 discipline that the *OCR* layer (not the VLM) is
    authoritative for exact strings. **No vector search.**
  - [Swift Paperless](https://github.com/paulgessinger/swift-paperless) — an actively
    maintained native iOS client, but a generic native scanner, not a mail-tailored
    capture flow, and iOS-only (not one Flutter cross-platform app).
  - **Coverage:** local ✓, household ✓, full-text ✓; mobile capture / local-VLM
    extraction *partial*; **missing entirely: semantic search, mail-native financial
    fields, a mail-tailored capture UX, single-app cohesion, guaranteed NL/DE/EN tuning.**
- **[paperless-ai](https://github.com/clusterzx/paperless-ai)** — AI middleware
  (Ollama/OpenAI) for title/tags/type/correspondent + "chat with your documents";
  weaker OCR, no vision emphasis, no structured financial fields, no semantic search.
- **Paperless-AIssist** ([discussion](https://github.com/paperless-ngx/paperless-ngx/discussions/12252))
  — newest (2025) middleware; local Ollama vision OCR, separate vision-vs-reasoning
  models, and **type-specific custom-field extraction** — the closest prior art to our
  §6.4 plan. Still no mobile capture and no semantic search. **Worth studying before we
  build extraction from scratch.**
- **[Docspell](https://docspell.org/), [Papra](https://github.com/papra-hq/papra),
  Mayan EDMS, Teedy** — self-hosted DMS with OCR/tagging, but **no local VLM
  understanding**, no mail-tailored photo capture, no semantic search. (Papra/Docspell
  are AGPL — a licensing watch-item if this ever became a hosted service; §6.8.)
- **[Khoj](https://github.com/khoj-ai/khoj) / [Morphik](https://github.com/morphik-org/morphik-core)**
  — self-hostable local-AI RAG/semantic search over documents. **Not mail archivers**
  (no capture, no correspondent/IBAN schema, no filing UX) — candidate *components*,
  not competitors.
- **[Genius Scan](https://geniusscansdk.com/docs/v5/document-scanning/structured-data-extraction/)**
  — mobile scanner with **on-device** OCR and structured extraction including **IBAN/BIC
  and receipt amounts** (per its iOS SDK docs). Proves capture-side local extraction is
  feasible, but it's a scanner SDK/app, not an archive with search.
- **Cloud snail-mail (Earth Class Mail, iPostal1, Shoeboxed, Evernote Scannable)** —
  confirm the market need but are cloud/third-party-in-the-data-path — the direct
  antithesis of this project's local-first requirement. Not comparable.

### The gap this project fills

The individual ingredients all exist somewhere; the **integration + mail-specific
tailoring + semantic layer + single cross-platform app + NL/DE/EN focus, fully
offline** is the whitespace. The project is **not redundant** — the novel value is a
coherent, mail-specific, semantic-enabled, fully-local product, while the archive core
itself is a solved problem worth mirroring/forking rather than rebuilding.

### Implications for build-vs-fork (§6.8)

- Reinforces §6.8's "mirror the Paperless data model" call — the ecosystem is mature and
  its data model is close to ours (§8), keeping a later migration cheap.
- **Reuse, don't reinvent, the extraction plumbing:** study **Paperless-AIssist**'s
  separate-vision/reasoning + type-specific field extraction before building §6.4.
- **The semantic-search layer (bge-m3 + sqlite-vec) is genuinely additive** — no
  Paperless plugin offers it; it stays our differentiator.
- **Convergence watch-item:** an *official* AI integration may eventually land inside
  Paperless-ngx and subsume the plugin layer. If it ships with local vision, our
  *extraction* edge narrows — but semantic search, the mail-tailored capture app, and the
  NL/DE/EN structured schema remain ours. Tracked as a follow-up.

---

*Next step: run Phase 0 (the feasibility spike) — synthetic-first letters (decision
log #5), with the owner's real letter photos re-benchmarked as they arrive — to
validate OCR + VLM extraction quality before committing to the full build.*
