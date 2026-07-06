# Design feedback — running log for the Claude Design project

Deviations and findings accumulated while implementing the `design/` mirror as
the native apps (`app/`). This file becomes the update prompt for the Claude
Design project at the end of the Native apps phase — every entry is something
the design should adopt, correct, or consciously reject. Add entries as they
happen; don't wait.

## Platform translations (design should document, not change)

1. **Fonts and icons are bundled, not CDN-loaded.** `tokens/fonts.css` imports
   Google Fonts and `readme.md` says "Lucide via CDN" — the shipped apps bundle
   Lora / Source Sans 3 / Source Code Pro (OFL) and the used glyphs as local
   path data instead (plan.md decision v0.5 #16, local-first). Suggest the
   design note this explicitly in readme.md "Type"/"Iconography".
2. **oklch → sRGB.** Flutter has no oklch; tokens are converted with CSS
   Color 4 reference math (`scripts/gen_flutter_tokens.py` →
   `app/lib/design/tokens.g.dart`). Conversion is deterministic and clamped;
   perceptually identical on sRGB displays. No design action — recorded for
   traceability.

## Findings the design may want to adopt

3. **Search placeholder doesn't fit a phone.** "Search your mail — words or
   meaning" (36 chars at 17px) cannot fit the mobile kit's own ~318pt input;
   CSS hard-clips it, Flutter ellipsizes ("…words or meani…"). Consider a
   shorter mobile placeholder (e.g. "Search your mail") or a smaller
   placeholder size. (QA finding, PR #32.)
4. **MetaRow edit affordance rule.** The JSX shows the pencil whenever
   `editable`; the app shows it only when a save handler exists (an
   editable-but-unwired row would render a dead button). Suggest the design
   adopt "affordance only when actionable".

6. **Chip: hover repaints a selected chip.** In the mirror,
   `.mfChip--interactive:hover` out-specifies `.mfChip--selected`, so hovering
   a selected chip swaps its accent tint for the generic hover surface. The
   app keeps selected styling stable under hover (reads as less glitchy).
   Suggest the design adopt `.mfChip--selected:hover` styling explicitly.
   (Senior review finding, PR #32.)

7. **Detail meta rows show the document date as ISO (`2026-03-12`), not
   "12 Mar 2026".** The row is inline-editable and the server only accepts
   ISO on save; a display/edit split would need a two-value MetaRow. Lists
   and cards keep the design's "12 Mar 2026". Options for the design: bless
   ISO in editable rows, or spec the display/edit swap explicitly.
   (App-shell PR.)

## Content / sample-data

5. **"Phone · Jasmijn"** (desktop kit, Settings → paired devices) may be a
   real household member's name; asked the owner on repo issue #23. If real:
   rename in the design and re-mirror. All other sample data is clearly
   fictional.
