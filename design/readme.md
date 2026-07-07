# Briefkist — Design System

*(Renamed from the working name "my-flopy" — the old name collided with an existing package. All brand attributes unchanged.)*

A private, local-first snail-mail archive. A phone photo of a physical letter becomes a clean, searchable, auto-tagged archive entry — processed entirely on hardware the owner controls (a Mac mini at home, reached over a private VPN). No cloud, no telemetry, no third party in the data path. It is an **archive**, not a finance tool: no amounts, no due dates, no bills.

Single-household product (1–3 people). Multilingual (Dutch / German / English) — identity is language-neutral. v1 is a web app; a native Flutter app follows, so patterns favour native idioms (tab bar, sheets, system camera).

**Sources:** design brief supplied in chat (no prior codebase, Figma, or assets — identity created from scratch on the client's request).

## Brand attributes

Private · local · calm · archival · personal · trustworthy · unfussy.

The feel: a beautifully kept personal filing cabinet that happens to be smart. Warm paper, ink, and postal cues — never a data-hungry SaaS. The floppy-disk × snail-mail pun lives in the mark and in occasional motifs (postmarks, disk labels) in empty states; it never turns kitschy in everyday UI.

## Voice & tone

- Calm, precise, quietly confident. Short declarative sentences. No exclamation marks, no hype.
- Second person, lowercase-friendly ("Your mail stays home."). Sentence case everywhere — buttons, titles, labels.
- The privacy promise is stated plainly where data moves (upload, pairing): "Processed on your own server." Never marketed, never repeated needlessly.
- No emoji in product UI. No jargon ("semantic embeddings" → "search by meaning").
- Errors are honest and specific, and always say what happens next: "Can't reach your home server. Your photos are kept on this device and will upload when you're back on your network."

### Copy examples
- Empty archive: "Nothing filed yet. Your first letter is one photo away."
- Processing: "Reading page 1 of 2…"
- Pairing: "This phone will talk only to your own server."
- Search placeholder: "Search your mail — words or meaning"

## Content fundamentals

- Titles are the document's own subject, in the document's language ("Wijziging zorgverzekering 2026"). UI chrome stays in the UI language.
- Dates: absolute and unambiguous — "12 Mar 2026" (day month-abbrev year), never "3/12".
- Categories are a closed list of 14: government, medical, insurance, bank, utility, telecom, legal, employment, education, housing, commercial, membership, personal, other. Shown as neutral chips, never color-coded per category.
- The pencil edit affordance appears only when a field is actually wired to save — never a dead button (as-built rule, adopted).

## Platform translations (as built — do not reintroduce CDNs)

The shipped native apps (Flutter, iOS + macOS — `app/` in github.com/nielsfilmer/briefkist) translate this design as follows. The design stays the source of truth; these notes prevent regressions:

- **Fonts & icons are bundled, not CDN-loaded.** Lora / Source Sans 3 / Source Code Pro ship as local OFL binaries; the used Lucide glyphs ship as local path data. The Google Fonts `@import` and Lucide CDN links in this project are web-preview conveniences only — production surfaces must bundle (local-first).
- **oklch → sRGB.** Flutter has no oklch; tokens are converted deterministically with CSS Color 4 reference math and clamped (`scripts/gen_flutter_tokens.py`). Perceptually identical on sRGB displays. No design action.

## Interaction rules surfaced by the build (adopted)

- **Dates:** editable metadata rows show and accept ISO (`2026-03-12`, mono) — the server only accepts ISO on save and a display/edit split isn't worth a two-value row. Lists, cards and prose keep "12 Mar 2026".
- **Correspondent and place are separate rows** in detail (separately corrected fields); correspondent displays name-only.
- **Selected chips stay selected under hover** — hover never repaints the accent tint.
- **Category quick-row shows all 14 categories**, horizontally scrolling; no curated subset.
- **Upload feedback is the row's status badge, not a toast** — one signal, not two. Pending-page trays scroll horizontally on overflow. Empty/offline upload lists show a quiet hint row. Failed rows show the failure detail as a wrapping line with a dismiss × (multi-sentence copy can't live in a pill). Done rows open the filed document. Capture/upload buttons disable while an upload is in flight.
- **Pairing is mint-on-demand:** tokens are minted per named device (server-enforced name uniqueness) — name field → "Create pairing code", never an always-visible QR. QRs render black-on-white, never themed (scanner contrast); 200px on phone screens. The mobile QR-scanner screen uses forced-dark chrome over the live camera feed. Device rows carry Revoke + "this device" on all platforms.
- **Mobile search placeholder** is the short form "Search your mail"; the long "… — words or meaning" form is desktop-only.

## Visual foundations

- **Color.** Warm paper neutrals (hue ~85, chroma ≤0.012) for surfaces; warm ink near-black for text. One accent: **plum ink** `oklch(0.50 0.10 320)` — stamps, primary actions, focus, links. Semantic tones (success/error/warning) share the accent's muted chroma. Dark mode is warm charcoal (never blue-black); paper becomes ink, ink becomes paper, plum lightens one step. Both modes ship as token themes (`:root` + `[data-theme="dark"]`).
- **Type.** **Lora** for document titles and brand moments (archival serif), **Source Sans 3** for all UI (calm, multilingual), **Source Code Pro** for references, tokens, dates-in-metadata and technical trust moments. Loaded from Google Fonts.
- **Backgrounds.** Flat paper tones only. No gradients, no imagery, no textures in chrome. The only "images" in the product are the user's own page scans.
- **Cards.** Paper-white on paper-tint background, 1px warm hairline border, radius 10px, elevation only on overlays (sheets, dialogs, menus). Shadows are soft, warm-tinted, never blue.
- **Borders & radius.** Hairlines `1px` in `--border`; radius scale 4/6/10/16 + full. Chips are full-round; cards 10; sheets 16 top corners.
- **Elevation.** 3 steps: flat (cards), raised (menus/toasts), overlay (dialog/sheet) — soft umbra, warm tint.
- **Motion.** Quiet: 150–200ms ease-out fades/slides. Sheets slide up 240ms. Processing states use a slow 1.6s pulse, never spinners-everywhere. No bounces.
- **Hover:** background shifts one paper step darker. **Press:** one further step + no scale tricks. **Focus:** 2px plum ring, 2px offset — always visible, keyboard-first.
- **Privacy mark.** A small "home" reassurance token (house glyph + "on your server") appears wherever data moves. It is informational, styled as a quiet mono caption — never a badge shouting.
- **Motifs (empty states & brand moments only).** Dashed postmark circle, wavy cancellation lines, disk-label rectangle. Drawn as simple geometric SVG in muted ink at low contrast.

## Iconography

- Stroke icons, 1.75px, rounded caps — **Lucide**. Web previews may load it from CDN; shipped apps bundle the used glyphs as local path data (local-first). Icons inherit `currentColor`.
- The mark (see `assets/`) is a floppy-disk outline whose label area is an envelope flap — one continuous geometric shape, works at 16px.
- No emoji, no filled icon styles, no two-tone.

## Accessibility

- Text contrast ≥ 4.5:1 in both themes (tokens are pre-checked); interactive hit targets ≥ 44px on touch; every control keyboard-reachable with the plum focus ring; status conveyed by text + icon, never color alone.

## Index

- `styles.css` — token entry point (imports everything below)
- `tokens/` — colors (light+dark), typography, spacing/radius/elevation, fonts
- `assets/` — logo mark + wordmark, postmark motif
- `guidelines/` — foundation specimen cards (Design System tab)
- `components/` — actions, inputs, display, feedback, navigation
- `ui_kits/mobile/`, `ui_kits/desktop/` — full screens, light/dark toggle built in
- Website (root `*.dc.html`) — public site: `Landing`, `Pricing`, `Security`, `Docs` + `Docs Article`, `Signup` (interactive hosted flow), `Account` (hosted dashboard), `Legal`, `Blog Article`, `404`, `Status Reference`; shared `SiteNav`/`SiteFooter` (theme toggle persists via `bk-theme` in localStorage)
- `SKILL.md` — agent skill entry point

### Intentional additions
No source component inventory existed; the standard set below was authored from scratch, sized to the screens in the brief (see `components/`).
