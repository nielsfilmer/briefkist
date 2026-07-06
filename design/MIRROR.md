# Design mirror — provenance

This directory is a **read-only local mirror** of the Claude Design project
"my-flopy — Design System"
(claude.ai/design project `f58233fe-52f5-4eb5-b105-aeadf6394ea8`), fetched via
DesignSync on 2026-07-06. It is the design source of truth the native apps
(`app/`) are built against. **Treat it as a vendored-asset directory**: don't
edit the mirrored files — changes belong in the Claude Design project, then
re-mirror. (This file, `MIRROR.md`, is the one repo-authored exception and may
be edited.)

> **CDN caveat (load-bearing — plan.md decision log v0.5 #16):**
> `tokens/fonts.css` @imports Google Fonts and `readme.md` says "Lucide via
> CDN". That is the *web design kit's* own convenience wording, mirrored
> verbatim. Anything shipped from this repo — the `app/` binaries and the
> `web/` fallback UI alike — **bundles fonts and icons locally; no CDN, no
> outbound fetch.** Don't copy those references into product code.

Mirrored (the implementable truth):

- `readme.md` — brand identity, voice & tone, visual foundations (verbatim).
- `tokens/` — colors (light+dark), typography, spacing/radius, elevation,
  fonts, base (verbatim CSS custom properties).
- `assets/` — logo mark, app icon, postmark motif (verbatim SVG).
- `components/**/*.jsx` — all 17 design-system primitives (verbatim).
- `ui_kits/kitdata.jsx`, `ui_kits/mobile/kit.mobile.jsx`,
  `ui_kits/desktop/kit.desktop.jsx` — the full screen designs (verbatim).

Deliberately not mirrored (presentation chrome of the design tool, duplicative
of the above): `guidelines/*.html` specimen cards, `components/**/*.d.ts`,
`components/**/*.prompt.md`, `components/**/demo.*.jsx`,
`components/**/*.card.html`, `ui_kits/*/index.html` mount shells,
`assets/mfload.js` + `assets/ios-frame.jsx` (kit loaders), `SKILL.md`,
`styles.css` (an @import list of `tokens/`), `.thumbnail`.
