# my-flopy — Design System

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
- Metadata is always editable in place; corrected fields get a small "corrected" tick, never a warning color.

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

- Stroke icons, 1.75px, rounded caps — **Lucide** via CDN (substitution: no bespoke set exists yet; flagged for later replacement with a custom set). Icons inherit `currentColor`.
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
- `SKILL.md` — agent skill entry point

### Intentional additions
No source component inventory existed; the standard set below was authored from scratch, sized to the screens in the brief (see `components/`).
