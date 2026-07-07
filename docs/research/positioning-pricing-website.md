# Research: Positioning, pricing & website structure

*Commissioned for the Productization phase (tracker #44); researched 2026-07-06/07 by a web-research agent; preserved verbatim as decision input. Prices/availability are point-in-time.*

---

All five research angles are complete and verified (unverifiable numbers flagged by the agents; the wedge hypothesis was adversarially stress-tested). Here is the synthesized report.

---

# Go-to-market research: my-flopy — local-first snail-mail archive for EU households

*Research date: 2026-07-06. Method: 5 parallel research threads (competitive landscape, pricing benchmarks, privacy messaging, two-tier framing, sitemap/legal), primary-source fetches wherever possible; unverified numbers are flagged.*

---

## 1. Competitive landscape 2026

### Paperless-ngx — the incumbent, and it just grew native AI
- **Positioning:** the de facto open-source self-hosted DMS — "transform your physical documents into a searchable online archive." Free (GPL), community-run, prosumer/homelab-centric.
- **Hosted:** no first-party hosting. Third parties: [PikaPods from ~$4.90/mo](https://www.pikapods.com/apps), [Paperless-Home €5–30/mo](https://paperless-home.com/pricing), [Elestio ~$16/mo infra](https://blog.elest.io/go-paperless-in-2026-how-paperless-ngx-organizes-your-documents-better-than-dropbox/), German B2B managed hosting (WZ-IT, from ~€79.90/mo — unverified snippet).
- **AI story — this changed materially in 2026:** native "Paperless AI" ([PR #10319](https://github.com/paperless-ngx/paperless-ngx/pull/10319), merged Jan 2026) shipped in [v3.0.0-beta.rc1 (May 2026)](https://github.com/paperless-ngx/paperless-ngx/releases/tag/v3.0.0-beta.rc1): LLM suggestions for tags/type/correspondent/title, document chat, RAG — backends OpenAI **or local Ollama**, opt-in, disabled by default. Crucially it's a **text LLM over already-OCR'd content, not vision-model extraction from the photo**. The vision piece exists as a sidecar: [paperless-gpt](https://github.com/icereed/paperless-gpt) (~2.5k stars, actively maintained, local Ollama vision OCR + metadata). [paperless-ai](https://github.com/clusterzx/paperless-ai) (~5.8k stars) is **"currently not maintained"** — the incumbent is absorbing its ecosystem's AI add-ons. The "paperless-ngx + Ollama" recipe is now mainstream homelab content ([XDA](https://www.xda-developers.com/paperless-ngx-with-a-local-llm/), [Tailscale blog](https://tailscale.com/blog/paperless-ngx-local-ai-document-search)).
- **Mobile capture:** no official app. [Swift Paperless](https://github.com/paulgessinger/swift-paperless) is the de facto iOS client (camera, share-sheet, Face ID); the Android Flutter app is discontinued/buggy. Capture is an upload client bolted on, not a designed-in pipeline; Android is the weak side.

### Papra — design-forward newcomer, explicitly no AI
- ["The minimalistic document archiving platform"](https://papra.app/en/) — AGPLv3, ethical/bootstrapped branding, for people who find Paperless heavy. **Cloud: Free / Plus $9/mo / Pro $30/mo**, EU-hosted, GDPR-marketed ([pricing](https://papra.app/en/pricing)). **AI: none** — rule-based tagging only; AI is in the "maybe one day" roadmap bucket. Mobile: unofficial iOS upload client only. Not photo-first.

### Docspell — capable but classical, slowing
- ["Simple document organizer"](https://docspell.org/) for home/SMB, AGPLv3. Free, no first-party hosting. AI = Tesseract OCR + **classical ML classifiers** — no LLM/VLM story. Android upload app; not photo-first. Last release [v0.43.0, March 2025](https://github.com/eikek/docspell/releases) — alive but pre-LLM-era.

### Mayan EDMS — enterprise workhorse, now with Ollama
- ["Free open source document management"](https://www.mayan-edms.com/) — Django enterprise DMS (workflows, retention, signatures). Advertises **local-or-remote Ollama integration** (NL search, summarization, extraction into workflows) per its [docs/marketing](https://docs.mayan-edms.com/chapters/features.html) — local AI on paper, but org-oriented and heavy for a household. No hosted pricing found; no phone-first capture.

### ecoDMS — the German commercial benchmark
- German on-prem DMS for [private users](https://www.ecodms.de/en/private-use) and SMEs, GoBD/GDPR archiving. **Private Edition €89 one-time** (per concurrent connection, 24-month updates) ([licensing](https://www.ecodms.de/en/ecodms-archiv/licensing-model)) — *the* price anchor for "household DMS you pay for." AI = 2018-era: auto-cropping, OCR, template/rule classification — no LLM/VLM semantics. Official ScanApp exists; UX is dated-corporate, German-market-centric.

### New entrants 2025–2026: no credible self-hosted local-AI archiver — but a cloud "mail AI" wave
No new self-hosted local-AI-first archiver product emerged (Show-HN/r/selfhosted sweeps returned RAG infra, not archivers). What did emerge validates the household problem while failing the privacy constraint:
- **[Papeer](https://papeer.ai/)** — "your fully personal bureaucracy agent": scan letters, AI summarize/translate/extract tasks. Cloud (German servers / Google Drive / BYO LLM keys).
- **[Papero](https://apps.apple.com/us/app/papero-ai-document-scanner/id6746059566)**, **[PaperAI](https://paperai.eu/)**, **[MailScan AI](https://apps.apple.com/us/app/mailscan-ai/id6755808186)** — same pattern: phone-first mail understanding, server-side (cloud) AI, freemium.
- **[LocalScan](https://www.localscan.app/)** — the most interesting: iOS scanner where "even the optional AI features run locally." But it's a single-device scanner utility — no server, no household archive, no cross-device search, no archival schema.
- **Platform encroachment is real but shallow:** iOS 26 shipped integrated scanning (Preview app), but Apple Intelligence does not auto-extract archive metadata or maintain an archive; Google's Gemini Drive auto-organization is cloud-only/paid — and Google had a [Gemini-scans-your-Drive-PDFs privacy scandal](https://www.techradar.com/pro/security/gemini-ai-platform-caught-scanning-google-drive-files-without-user-permission) that actively feeds privacy-absolute positioning.

### The wedge hypothesis — adversarially tested
> "Phone-photo-first + local VLM auto-metadata + household-not-business + privacy-absolute — nothing else owns that."

**Verdict: survives, narrowly, with an expiry date.**
- **Strongest refutation attempt #1:** the Paperless-ngx v3 + paperless-gpt + Swift Paperless stack has *every individual capability* today — but as a 3-component DIY assembly (Docker Compose, unauthenticated sidecars, prompt tuning, broken Android). It refutes "no one *can* do this," not "no one *owns* this as a product."
- **#2 LocalScan:** four-for-four on adjectives but it's a scanner utility, not a multi-year searchable archive.
- **#3 The cloud mail-AI cohort** owns exactly your user story (households drowning in letters, phone-first, auto-understanding) — with a third party in the data path. It confirms the need is real and the *privacy-absolute* variant is unclaimed.
- **Caveats:** (1) it's an **integration/UX wedge, not a capability wedge** — every ingredient is commoditized ([Ollama + Qwen3-VL is a published recipe](https://ollama.com/blog/qwen3-vl)); (2) Paperless-ngx v3 is converging from one side and one good official mobile app would close much of the gap; (3) the cloud apps could add an on-device mode. Lean on what's hardest to copy: **the packaged household operator experience — one box, one app, zero cloud, EU-clean licensing** — not the AI itself.

---

## 2. Hosted pricing benchmarks

### Direct comparables (managed Paperless-ngx)
Consumer-managed Paperless clusters at **€5–16/mo — none with AI/VLM extraction**: PikaPods from $4.90/mo ([apps page](https://www.pikapods.com/apps)), Paperless-Home €5/€15/€30 ([pricing](https://paperless-home.com/pricing)), Elestio ~$16/mo. B2B managed jumps to €80+. Cloud68 doesn't list Paperless at all.

### Privacy-subscription anchors (what EU privacy consumers already pay)
| Product | Monthly |
|---|---|
| Tuta Revolutionary | €3 ([source](https://tuta.com/blog/announcement-new-prices)) |
| Proton Mail Plus | €4.99 (€3.99 annual) ([source](https://proton.me/support/proton-plans)) |
| Mullvad | €5 flat incl. VAT ([source](https://mullvad.net/en/pricing)) |
| Tuta Legend | €8 |
| Proton Unlimited | €12.99 (€9.99 annual) |
| Proton Family | €29.99 |
| Bitwarden Premium | ~$1.65 ([source](https://bitwarden.com/pricing/)) |

The well-trodden EU privacy price points are **€3, €5, €8–10, €12.99**; €12.99 is the practical single-product ceiling; family bundles reach €20–30. *(Flagged unverified: Ente and Standard Notes exact plans — pages blocked/JS-rendered.)*

### Infrastructure cost floor (verified July 2026, post-Hetzner-increase)
- 8 GB single-tenant box (Hetzner CAX21 €10.49 ex VAT, [Netcup VPS 1000 G12 €10.37 incl. VAT](https://www.netcup.com/en/server/vps)): a 4-bit 4B VLM fits, but CPU prefill = **minutes per page** — workable for queued household mail, sluggish otherwise. Comfortable single-tenant = 16 GB tier, **€19–25/mo incl. VAT** before storage/backups/ops. True single-tenant COGS ≈ **€11–25/tenant/mo** → €8–20/mo retail is only viable at the tight end.
- **Shared-GPU/queue model changes everything:** one Hetzner GEX44-class GPU box (~€184/mo, flagged: price via secondary listing) runs a 4B VLM at seconds/document and serves 50–150+ households → **€1.50–4/tenant inference + €2–4 app container = blended COGS €4–8/tenant/mo**, still on operator-controlled EU hardware. The honest label is "single-tenant instance, pooled EU inference queue."

### Conclusion
**Credible band: €9–19/mo; headline ~€12/mo (≈€9–10 effective annual), premium true-single-tenant at €19–24/mo.** At €12 with pooled inference, gross margin ~35–65%. Below €8 you fight PikaPods DIY on price while carrying GPU costs they don't — the free self-host tier already serves that segment. EU consumer norm: advertise **VAT-inclusive** (budget ~19–21% of sticker).

---

## 3. Privacy-product messaging that works

### The shared template (Proton, Tuta, Signal, Standard Notes, Immich, Home Assistant, Jellyfin — all fetched live)
1. **Hero = 2–4-word emotive headline about the user's freedom + plain-language subhead + free-forward CTA.** "Speak Freely" (Signal), "Free your mind." (Standard Notes), "Turn ON Privacy" (Tuta), "Awaken your home" (HA). Privacy is the *second* clause, benefit first — Immich: "…organize… your photos and videos with ease, **without sacrificing your privacy**."
2. **Immediate proof strip:** commercial products use user counts/press/ratings (Proton: "100 million users", CERN origin, "Swiss privacy"); OSS projects use **a screenshot + live demo + GitHub** (Immich's homepage proof *is* the screenshot; the demo instance is the conversion workhorse).
3. **Feature sections, each with its own CTA.**
4. **A "why we're different" trust section unique to this genre:** governance (Signal: "we can never be acquired"; nonprofit foundations), jurisdiction ("Made in Germany", "Swiss privacy"), funding model. Standard Notes' block is the best template for a young product: **"100% Revenue from paying users / $0 in venture capital / 10 years in service"** — swappable for architecture claims like "0 outbound connections from the processing path."
5. **Concrete adversary framing:** Tuta's "Turn OFF Surveillance"; Signal's "No ads. No trackers. No kidding."; Standard Notes names adversaries (government, employer, breach) and uses **concrete nouns** ("Passport and ID photos… Legal contracts… Health records") — directly transferable to a mail archive.
6. **Forever-free reassurance near the bottom; pricing is one click away, never the hero.**
7. **Footer = trust archive:** source code, audits, transparency reports, comparison pages.

### Trust builders by vendor
Proton: audits + [transparency report](https://proton.me/legal/transparency). Tuta: 6-monthly transparency report **with warrant canary**. Signal: [signal.org/bigbrother](https://signal.org/bigbrother/) — publishes actual subpoenas. Standard Notes: **"Read our security audits" as a homepage CTA** (Trail of Bits, Cure53). Immich: GitHub (~107k stars) is the trust engine; FUTO in the logo.

### The differentiating gap
**Nobody puts threat-model honesty on the homepage** — the honest ones bury it one click deep, and academic work confirms overclaiming is the industry failure mode ([CHI 2025 study of VPN marketing claims](https://dl.acm.org/doi/10.1145/3706598.3713980); [Proton's own threat-model post](https://protonvpn.com/blog/threat-model) is the in-house exception). A short on-page "what we protect against / what we don't" section would be genuinely differentiating for a privacy-absolute product.

---

## 4. The honest two-tier story

Key precedents and the patterns they yield:

- **Immich/FUTO:** no hosted tier at all — a voluntary product key: "we ask users to pay for the software, especially if they find it useful… there are still no features that require payment" ([blog](https://immich.app/blog/futo-two-years-later)). Proof people pay self-hosted software with zero leverage.
- **Bitwarden:** "tradeoffs between **convenience and control**," never privacy-vs-privacy — possible because E2EE makes privacy deployment-independent ([resource page](https://bitwarden.com/resources/cloud-based-password-manager-or-self-hosted/)). Tolerates Vaultwarden gracefully.
- **CryptPad:** flagship subscriptions openly fund development ([funding-status posts](https://blog.cryptpad.org/2026/02/18/CryptPad-Funding-Status-2026/)); [security docs](https://docs.cryptpad.org/en/user_guide/security.html) assert the strong claim then **enumerate residual exposure** (IP, user agent, JS-serving trust) — the honesty is what makes the claim credible.
- **Plausible:** the best "neither undersold" page — cloud: "all done for you"; self-host: "You do it all yourself" ([self-hosted page](https://plausible.io/self-hosted-web-analytics)); privacy identical in kind, residual difference is jurisdictional.
- **Nabu Casa / Home Assistant Cloud:** paid tier is an add-on to *your* instance, funds the foundation; and the single best sentence for the AI angle: **"Speech processing is never stored or used to train any models"** ([nabucasa.com](https://www.nabucasa.com/)) — when processing must touch plaintext, the honest claim is about **retention and training, not visibility**.
- **Standard Notes** is the cautionary pole: self-hosters must still buy a subscription to unlock features — exactly the "self-host is second-class" perception to avoid.
- **Plaintext-processing precedents (your exact constraint — hosted OCR/VLM can't be E2EE):** [PikaPods' privacy page](https://www.pikapods.com/privacy) uses **purpose limitation** instead of a false zero-knowledge claim ("You give us permission to use that data solely to do what's necessary to provide our services"), plus German residency and full deletion. [Elestio](https://elest.io/open-source/paperless-ngx) sells **single-tenant VMs + choose-your-country + migrate-off-anytime**. German Paperless hosts sell residency + ISO + GDPR — none claims "we can't see your documents." **The market norm for plaintext processors is: residency + isolation + certification + purpose limitation + deletability — not zero-knowledge theater.**

**The formula for my-flopy's hosted tier:** (a) convenience-vs-control axis, (b) purpose limitation instead of fake E2EE, (c) single-tenant + EU + exit-anytime concreteness, (d) "never retained beyond processing, never used for training, no third-party APIs — and your subscription funds the open-source project," (e) a CryptPad-style docs page stating outright what the operator *could technically* see and what architecture/policy does about it.

---

## 5. Website structure

### What comparable solo/tiny-team products actually ship
The universal solo-operator core is five things: **landing, pricing, docs, blog, privacy+terms — plus a status page once you charge money** (Healthchecks.io, ntfy, Miniflux all have one). [Cal.com launched on essentially one page](https://www.producthunt.com/stories/how-this-open-source-calendly-alternative-rocketed-to-product-of-the-day). Most peers route self-hosting through docs/pricing rather than top nav.

### What converts (founder evidence)
- **Blog = traffic engine, comparison pages = conversion engine** ([Plausible's $1M-ARR retrospective](https://plausible.io/blog/open-source-saas): viral posts drove 25k visitors/day; their nav now carries ~20 comparison/SEO pages). Comparison/alternative pages convert ~7.5% vs fractions of a percent for informational content ([Grow & Convert analysis](https://www.usegrowthos.com/blog/how-to-build-saas-comparison-pages)); a *"when NOT to use this"* page was one founder's best converter at 13.8% — very on-brand for privacy honesty.
- **"Self-host vs cloud" is a paragraph on the pricing page at launch**, not a page — the job is reassuring the payer they aren't a sucker and reminding fence-sitters ops burden is real ([Plausible's CE framing](https://plausible.io/blog/community-edition)).

### EU legal minimums (NL operator, verified)
Required at launch: **imprint/company details** (NL BW 3:15d: name, address, email, KvK, btw-id — and German-Impressum-grade once you target DE, [source](https://business.gov.nl/regulations/rules-business-correspondence/)); **GDPR privacy policy**; **terms incl. 14-day withdrawal instructions + model form** ([Your Europe](https://europa.eu/youreurope/citizens/consumers/shopping/returns/index_en.htm)); **VAT-inclusive B2C prices** (OSS scheme past €10k cross-border). Notes: the **EU ODR-platform link is repealed** (platform shut July 2025 — don't copy old templates); a **withdrawal button in-UI** is required from 19 June 2026 (Directive 2023/2673) — build self-serve cancellation day one; microenterprises are **exempt from the European Accessibility Act**; no cookie banner if you skip non-essential cookies (on-brand); no DPA until B2B asks.

### i18n
Small-team norm is EN-only at launch (even German Formbricks!) — but the products winning German *households* are German-first (Tuta, ecoDMS), and German consumers convert far better in German and punish translation errors. **Launch EN + NL (native, free to maintain); do DE as the first growth investment, native-quality or not at all.** Shipping a DE site legally triggers the Impressum duty — which you'll already satisfy.

---

# Recommendations

## Positioning statement (draft)

> **my-flopy turns the paper mail piling up at home into a private, searchable family archive.** Photograph a letter with your phone; your own server reads it, understands it, and files it — sender, date, summary, keywords — using AI that runs entirely on hardware you control. No cloud, no third party, nothing to train on your life: self-host it for free, or let us run a dedicated EU instance for you.

(Follows the genre rule: benefit first — "every letter, findable forever" energy — privacy as the closing clause; the honest two-path fork built into the last sentence.)

## Recommended pricing + tier table

**Headline: €12/mo (or €9/mo billed annually), VAT-inclusive.** Sits at the top of the hosted-Paperless band (justified by AI extraction none of them offer), just under Proton Unlimited (€12.99), at 35–65% gross margin on pooled-inference COGS of €4–8/tenant.

| | **Self-host** | **Hosted** — €12/mo (€9/mo annual) | **Dedicated** — €24/mo (€19/mo annual) |
|---|---|---|---|
| Software | Full product, free forever, AGPL — no paywalled features (Immich model) | Same code we run ourselves | Same |
| Runs on | Your hardware, your network | Your own single-tenant instance, EU datacenter | Single-tenant instance + your own dedicated inference runner |
| AI processing | 100% on your box | Pooled EU inference queue (operator hardware; never retained beyond processing, never trained on) | Reserved inference capacity |
| Who can see documents | No one but you | Us, technically, during processing — purpose-limited by policy + architecture; stated plainly | Same, smaller surface |
| Storage | Unlimited (yours) | ~20 GB | ~50 GB |
| Ops, backups, updates | You | Included | Included |
| Exit | n/a | Full export anytime, one-click delete | Same |
| What paying funds | Optional supporter key later | Development of the open-source project | Same |

## Recommended sitemap

**Launch day (8 pages + repo):**
1. `/` **Landing** — hero promise, screenshot, the two-path fork (self-host free ⭤ hosted from €9), one-diagram privacy architecture, concrete nouns ("tax letters, insurance, municipality, medical"), short on-page "what we protect against / what we don't."
2. `/pricing` — VAT-inclusive; self-host as the free column; the convenience-vs-control paragraph lives here.
3. `/docs` — install/self-host guide + user guide; the #1 solo support-deflection asset.
4. `/security` — the data-path page: what's stored where, what never leaves, what the hosted operator could technically see and the policy/architecture answer; link to code. **A conversion page, not compliance.**
5. `/imprint` — NL + German-Impressum-compliant.
6. `/privacy` — GDPR policy; no non-essential cookies → no banner.
7. `/terms` — 14-day withdrawal + model form, self-serve cancellation, no ODR link.
8. **Status page** (external hosted service) — one hour of work, outsized trust for a paid solo product.
9. **GitHub README** — substitutes for about/changelog/roadmap for the self-host audience; include a live **demo instance** link as soon as feasible (the Immich conversion workhorse).

**Fast-follow (weeks 1–12, in order of expected return):** `/blog` (launch post day one; the Plausible traffic engine) → comparison pages: *"vs. the shoebox"* (category creation), *vs. Paperless-ngx*, *vs. ecoDMS*, and a *"when NOT to use my-flopy"* honesty page → **`/de/` full-funnel native-quality German** (+ NL alongside) → `/about` (the solo-EU-operator story is a trust asset) → human-readable changelog → DPA only when B2B asks.

**Key strategic caveat to carry into everything:** the wedge is real today but it is an integration/UX wedge with a visible expiry — Paperless-ngx v3's native local AI is converging from one side, cloud mail-AI apps from the other. The moat to build and message is the *packaged household experience* (phone-to-archive in one motion, one box, zero cloud, EU-clean licensing), not the AI capability itself.