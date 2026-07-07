# Design feedback — update prompt for the Claude Design project

**Status: ready to send** (build-out complete 2026-07-06; the phase closes
after the owner's real-device pass). This file doubles as the paste-ready
prompt below and the repo's running deviation log.

---

## The prompt (paste into the Claude Design project chat)

> The Briefkist design system was implemented as native Flutter apps (iOS +
> macOS) — every screen in `ui_kits/` is now real software talking to the
> FastAPI backend. Update the design project to match the as-built product.
> The numbered findings below are the deltas; for each, either adopt it into
> the kits/components/readme, or consciously reject it (and say why) so the
> app can follow the design back. Key asks:
>
> 1. Document the platform translations (bundled fonts/icons, oklch→sRGB) in
>    readme.md — the design stays the source of truth, the note prevents a
>    future implementer reintroducing CDNs (findings 1–2).
> 2. Adopt the interaction fixes the build surfaced: actionable-only edit
>    affordances, selected-beats-hover chips, correspondent/place as separate
>    rows with name-only display (findings 4, 6, 9).
> 3. Rework the pairing screens around mint-on-demand (named tokens with
>    server-enforced uniqueness) and add the mobile QR-scanner screen the kit
>    lacks (finding 11).
> 4. Add the capture/upload states the kits under-specified: scrolling pending
>    tray, badge-not-toast upload feedback, empty/offline hint rows, failed
>    rows with detail + dismiss (finding 10).
> 5. Fix the copy that can't fit or is no longer true: the mobile search
>    placeholder, ISO dates in editable rows (findings 3, 7).
> 6. Sample data: answer the "Phone · Jasmijn" question (finding 5) and
>    rename if real.
>
> The as-built implementation is at github.com/nielsfilmer/my-flopy under
> `app/` (fresh screenshots of any screen can be captured on request).

---

## The findings (the log below is the prompt's payload)

Deviations and findings accumulated while implementing the `design/` mirror as
the native apps (`app/`) — each is something the design should adopt, correct,
or consciously reject.

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

8. **Mobile category chip row shows all 14 categories** (horizontally
   scrolling); the kit's quick-row samples 6. With a closed 14-item list a
   curated quick-row is arbitrary — the app scrolls the full set. Design
   could bless this or spec a "top categories by count" rule. (PR #36 QA.)
9. **Correspondent and place are separate rows in detail** (they're separate,
   separately-corrected fields); the kit merges "name · place" into one
   editable row, which double-displayed place once a place row exists.
   Suggest the design split them as built. (PR #36 QA.)

10. **Capture/upload deviations (PR #39).** Pending-page tray scrolls
    horizontally when pages overflow (kit mock never overflows); mobile
    upload feedback is the row's "Uploading…" badge, not the kit's toast
    (one signal, not two); recent-uploads lists render a quiet hint row when
    empty/offline (kit only shows populated); capture/upload buttons disable
    while an upload or the picker is in flight (double-tap guard); failed
    pending rows show the failure detail as a wrapping line + dismiss ×
    (multi-sentence copy can't live in a 24px pill); done rows are tappable
    (open the filed document); desktop copy "Photos or PDFs" → "Photos"
    (PDF import is a later phase); pending rows say "Letter · N pages";
    onboarding step 2 says "copy its address into settings" until QR pairing
    ships (superseded — QR pairing shipped in the pairing PR; step 2 is back
    to the kit copy). Design could adopt the tray scroll, the badge-not-toast
    rule, and the empty-list hints.

11. **Pairing implementation notes (pairing PR).** (a) The kit shows an
    always-visible QR on the settings pair card, but tokens are minted per
    named device with enforced name uniqueness — so both surfaces replaced it
    with a mint-on-demand flow: name field → "Create pairing code". (b) A QR
    scanner screen exists on mobile (the kit has none), with forced-dark
    chrome over the live camera feed (the feed isn't themed, so themed chrome
    would be illegible in light mode). (c) QRs render black-on-white, never
    themed — scanners need the contrast. (d) Mobile device rows gained
    Revoke + "this device" (kit mobile rows show only paired dates). (e) The
    mobile QR renders at 200px vs the kit sheet's 160px (scan reliability at
    arm's length). Design could adopt the mint-on-demand card, spec the
    scanner screen, and bless the QR contrast/size rules.

## Content / sample-data

5. **"Phone · Jasmijn"** (desktop kit, Settings → paired devices) may be a
   real household member's name; asked the owner on repo issue #23. If real:
   rename in the design and re-mirror. All other sample data is clearly
   fictional.
