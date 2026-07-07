# Research: Open-source distribution, licensing & naming facts

*Commissioned for the Productization phase (tracker #44); researched 2026-07-06/07 by a web-research agent; preserved verbatim as decision input. Prices/availability are point-in-time.*

---

All research complete. Here is the report.

---

# my-flopy open-source launch research report

*(Research date: 2026-07-07. Repo state checked read-only: notably, the public repo currently has **no LICENSE, CONTRIBUTING, SECURITY.md, or `.github/` dir at all** — under default copyright a public repo without a license is *source-available, all rights reserved*, i.e. not yet open source in any legal sense.)*

## 1. License choice

### What the comparables chose

| Project | License | Monetization | CLA? |
|---|---|---|---|
| [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) | GPL-3.0 (inherited from the original Paperless fork) | None — pure community project | No |
| [Immich](https://immich.app/blog/immich-joins-futo) | AGPL-3.0 | FUTO salaries + **voluntary** lifetime supporter licenses ($99.99/server, $24.99/user); ["there will never be any paywalled features"](https://github.com/immich-app/immich/discussions/11186) | **No CLA** — stayed AGPL after joining FUTO |
| [Papra](https://github.com/papra-hq/papra) — the closest analog: solo-founder document archiver, AGPL + own paid cloud | AGPL-3.0 | [Managed cloud at papra.app](https://papra.app/en/pricing/) (Free 512 MB / $9 Plus / $30 Pro, EU data residency) while self-hosting stays free | No CLA mentioned; Discord + GitHub Discussions community |
| [Docspell](https://awesome-selfhosted.net/tags/document-management.html) | GPL-3.0 | None | No |
| [Tube Archivist](https://github.com/tubearchivist/tubearchivist) | GPL-3.0 | Donations/members container | No |
| [Plausible Analytics](https://plausible.io/blog/community-edition) | AGPL-3.0 ("Community Edition") | Paid cloud is the *only* revenue source; CE gets 2 long-term releases/year vs continuous cloud | No |
| Sentry / [Liquibase](https://www.liquibase.com/blog/liquibase-community-for-the-future-fsl) et al. | [FSL "Fair Source"](https://fsl.software/) (converts to Apache-2.0/MIT after 2 years) | Blocks competitors from offering the product as SaaS | Yes (needed for FSL) |

### The key legal fact for your model

**Selling hosting of your own AGPL project requires no CLA and no dual license.** AGPL restricts *others who modify and serve* the code (they must publish their modifications); it never restricts the copyright holder, and it doesn't even stop competitors from hosting it — it only forces them to share their changes. That's exactly the Plausible/Papra model. You only need a **CLA** if you may later want to (a) sell *proprietary/closed* enterprise editions, or (b) relicense (the HashiCorp/Elastic path, which [burned community goodwill](https://opensource.com/article/18/3/cla-vs-dco-whats-difference)). The 2025-era consensus: [DCO for community trust, CLA only for dual-licensing businesses](https://osr.finos.org/docs/bok/artifacts/clas-and-dcos); CLAs measurably suppress contributions.

- **Apache-2.0/MIT**: maximizes adoption but lets a competitor take the code and out-host you with zero obligations ([no protection against direct SaaS competition](https://www.getmonetizely.com/articles/what-open-source-license-protects-your-saas-business-model-best)).
- **BSL/FSL "fair source"**: protects the SaaS but is [not open source by OSI definition](https://techcrunch.com/2024/09/22/some-startups-are-going-fair-source-to-avoid-the-pitfalls-of-open-source-licensing/) — the self-host community (r/selfhosted, awesome-selfhosted, which *excludes* non-OSI licenses) reacts badly; overkill for a project whose users are privacy-minded individuals, not enterprises.
- **AGPL-3.0**: the de-facto standard for "self-host free forever + founder-run paid cloud" in this exact niche (Immich, Papra, Plausible, Papermerge, Stirling-PDF).

### Recommendation

**AGPL-3.0 + DCO (sign-off), no CLA.** It's what your two closest comparables (Immich, Papra) use; it keeps the self-host community onside; it fully permits your paid SaaS; and it prevents a proprietary competitor fork. Accept the one trade-off consciously: without a CLA you can never relicense to closed/BSL later without contacting every contributor. If you want to keep that door open, use a light CLA from day one (before contributors arrive) — but expect friction, and note Immich deliberately chose not to. One nuance: with external AGPL contributions you also can't paywall *cloud-only proprietary features built into the same codebase*; keep any future proprietary SaaS glue (billing, multi-tenant control plane) in a separate private repo, the standard open-core-adjacent pattern.

## 2. Cross-platform install story

### The distribution expectation in this niche

**Docker Compose is the table-stakes default.** Paperless-ngx's docs describe Docker Compose as "the easy way" and bare metal as ["the hard way… best suited for advanced users and contributors"](https://docs.paperless-ngx.com/setup/); the README leads with a one-liner install script that generates a compose file. Immich is compose-only-ish; Papra is "docker run one-liner". A bare-metal guide is **still expected but explicitly second-tier** — Paperless keeps one and the community [still asks for it to be easier](https://github.com/paperless-ngx/paperless-ngx/discussions/3798), but nobody treats it as the launch blocker.

### What a credible Linux/Docker path needs for THIS stack

- **OCR is the real porting problem, not Ollama.** Apple Vision (`pyobjc-framework-Vision`, already gated behind `sys_platform == 'darwin'` in `pyproject.toml`, with a clean engine abstraction + `available_engines()` in `spike/ocr_engines.py`) simply doesn't exist off macOS. Linux = PaddleOCR becomes the *primary*, so the Phase 0 benchmark delta between the two engines becomes user-facing honesty material ("expect X pp lower OCR accuracy on Linux" or the reverse).
- **PaddleOCR on Linux, 2026 status:** x86_64 CPU wheels are routine (`pip install paddleocr` + `paddlepaddle`); **aarch64 Linux is CPU-only** — [no official ARM64 GPU binaries](https://github.com/PaddlePaddle/PaddleOCR/discussions/17328), and there are live version-pinning landmines ([PaddleOCR 3.3 + Paddle 3.0 broke in Docker on both archs](https://github.com/PaddlePaddle/Paddle/issues/76111)). Ship a **pinned, tested combo** in your image; PP-OCRv5_mobile is designed for CPU-only (~[370 chars/sec on a Xeon core](https://arxiv.org/html/2507.05595v1)), so a Pi5/NUC-class box is fine. Your pyproject already treats paddle as an optional extra with a "wheels are hit-or-miss" comment — that inverts on Linux.
- **Ollama:** first-class on Linux; standard pattern is the official `ollama/ollama` container in the compose stack with a model volume + [NVIDIA Container Toolkit device reservations for GPU](https://docs.ollama.com/docker), or a host install (curl|sh) with the app pointed at `OLLAMA_HOST`. **Support both** (compose service by default, `OLLAMA_URL` env to use an existing host install — many self-hosters already run Ollama). Critical macOS caveat: Docker on Mac cannot pass through Metal, so on Macs Ollama must stay a host process — which means your compose file should treat Ollama as *optional/external* rather than hard-coded.
- **sqlite-vec:** a non-problem — the [PyPI package ships prebuilt wheels for manylinux x86-64 and aarch64 plus macOS](https://alexgarcia.xyz/sqlite-vec/python.html), loaded via `sqlite_vec.load()`. Only caveat: the Python interpreter must be built with `--enable-loadable-sqlite-extensions` ([Debian/Ubuntu system pythons are; pyenv builds sometimes aren't](https://alexgarcia.xyz/sqlite-vec/installation.html)) — inside your own Docker image you control this entirely. You pin `sqlite-vec==0.1.6`; fine.
- **Bare-metal guide:** yes, keep one — your current `uv run python -m server.app` + launchd `deploy/` story *is* the macOS bare-metal guide already, and it's actually your best-tested path. Frame it Paperless-style: "Docker Compose (Linux, recommended) / native install (macOS Apple Silicon, what the author runs; gets you Apple Vision OCR + Metal)". That macOS-native = better-OCR-and-faster framing turns the mac bias into a feature instead of a bug.
- **Egress lockdown** (a plan.md load-bearing feature) actually gets *easier* in Docker: an internal-only network for the worker/OCR containers is a one-liner in compose — worth advertising.

## 3. Repo productization checklist (from Paperless-ngx / Immich / Papra)

What the successful ones all have ([Paperless-ngx README](https://github.com/paperless-ngx/paperless-ngx), [Papra README](https://github.com/papra-hq/papra/blob/main/README.md), [Immich docs](https://docs.immich.app/install/requirements/)):

- **README**: one-paragraph pitch → hero screenshot/GIF → features list → link to a **live demo** (Paperless: demo.paperless-ngx.com demo/demo; Papra: demo.papra.app client-side-only — a clever zero-cost trick) → quickstart (copy-paste compose or one-liner script) → docs link → community links → contributing → license badge.
- **Docs site** (mkdocs-material is the niche standard, e.g. docs.paperless-ngx.com): setup, configuration reference (env vars!), administration (backup/restore, **updates & migrations** — Paperless documents `docker compose pull` + automatic migrations; a migration story is expected before v1.0), FAQ, troubleshooting.
- **Hardware requirements page** with a table (Immich: [min 6 GB RAM/2 cores, rec. 8 GB/4 cores, amd64+arm64](https://docs.immich.app/install/requirements/); Tube Archivist: 2–4 GB). Honesty here is a trust signal in this community.
- **SECURITY.md / security stance**: Paperless-ngx's README carries an explicit "run on trusted hosts only" warning; you have a stronger story (overlay-only, egress lockdown) — lead with it, plus a vulnerability-report channel.
- **Versioning + releases**: semver-ish tags, GitHub Releases with changelogs and explicit breaking-change callouts; Paperless ships frequent patch releases (v2.20.15, 149 releases), Immich cut a [stable 1.0 only in late 2025](https://alternativeto.net/news/2024/5/immich-joins-futo-to-enhance-development-of-open-source-photo-and-video-backup-solution/) after years of "breaking changes possible" banners — starting at `v0.x` with a "pre-1.0, read release notes before updating" banner is accepted practice.
- **Community**: GitHub Discussions (feature requests) + Issues (bugs, with templates) at minimum; Discord (Papra, Immich) or Matrix (Paperless) once there are users. CONTRIBUTING.md + Code of Conduct (Contributor Covenant is the default) are expected but short.
- **CI badges**: tests + published Docker image on GHCR/Docker Hub. A `latest` + versioned image tags are assumed by this audience.

**Repo-specific gaps found:** no LICENSE (blocker), no CONTRIBUTING/SECURITY/CoC/issue templates, README is builder-facing (leads with plan.md/CLAUDE.md and "the owner's 8 GB M1 Mac mini") rather than adopter-facing, no screenshots, no Docker anything ("no Docker" is currently a stated stack decision — fine for the author's deployment, but it can't be the *distribution*), docs/RUNBOOK.md is single-owner-voiced.

## 4. Naming facts (no decision)

- **`flopy` is hard-taken**: [USGS's FloPy](https://pypi.org/project/flopy/), the standard MODFLOW groundwater-modeling package — PyPI name taken (checked: HTTP 200), 3.10.x actively released, [github.com/modflowpy/flopy](https://github.com/modflowpy/flopy), USGS-backed. Any "flopy"-derived name will lose every search battle and can never have the PyPI name. `my-flopy` itself: PyPI **free** (404), GitHub effectively unique, `my-flopy.com` unregistered — but SEO/confusion risk with FloPy is permanent, and the name reads as a placeholder (which plan.md line 10 says it is).
- **Postvault**: 14 small GitHub repos named PostVault (all 0-star toy projects); PyPI `postvault` **free**; `postvault.com` **registered**, `.app`/`.io` **available**. Lowest-collision of the three.
- **Mailcrate**: 3 GitHub repos (one a 9-star mock SMTP server — mild dev-tool confusion); PyPI **free**; `mailcrate.com` **registered**, `.app` **available**. Note: "mail" names all suffer e-mail-tool confusion, relevant since Postal/MailVault etc. crowd the space — arguably a worse ambiguity for a *snail*-mail product.
- **Briefkist**: zero GitHub repos, PyPI **free**, `.com`/`.nl`/`.app` all **available** — cleanest slate, but collides conceptually with the established `briefkasten` projects (ndom91's bookmarking app, ZeitOnline's whistleblower box) and is opaque to non-Dutch/German speakers.
- (Checks: PyPI JSON API, GitHub search API, RDAP; `flopy.app` rate-limited (429) — unverified.)

## 5. Hardware requirements honesty

- **Model sizes ([Ollama library](https://ollama.com/library/qwen3-vl)):** qwen3-vl 2B = 1.9 GB, 4B = 3.3 GB, 8B = 6.1 GB download; resident memory during inference roughly 1.5–2× that with KV cache/vision encoder.
- **Apple Silicon:** your own production floor is the proof point — 4B runs on an **8 GB M1 mini sharing with Plex/Sonarr** (per CLAUDE.md/plan.md). That's the honest documented minimum for the Mac path: 8 GB works for 4B with nothing else heavy running; 16 GB comfortable.
- **x86 + NVIDIA GPU:** Qwen3-VL-4B Q4 fits in [~6 GB VRAM (8B needs ~12 GB)](https://codersera.com/blog/qwen3-vl-4b-vs-qwen3-vl-8b-benchmarks-vram-guide/) — i.e. any 8 GB card (RTX 3060-class) handles 4B at interactive speed (~60–70 tok/s reported).
- **CPU-only x86:** works but slow — community guidance is [16 GB RAM minimum for 4B-class models, 32 GB comfortable](https://apxml.com/models/qwen3-4b), and generation runs [single-digit tokens/sec](https://localaimaster.com/blog/ollama-system-requirements), with VLM prompt/image encoding adding noticeable per-page latency; a letter that takes ~tens of seconds on the M1 could take several minutes CPU-only. Your architecture absorbs this well (sequential background worker, not interactive) — say exactly that: "CPU-only works; expect minutes per letter, processed in the background."
- **PaddleOCR:** PP-OCRv5_mobile is explicitly [built for CPU-only deployment (~5M params, >370 chars/sec/core)](https://huggingface.co/blog/baidu/ppocrv5) — a rounding error next to the VLM; budget ~2 GB extra RAM for the paddle runtime. ARM64 Linux = CPU-only for Paddle (no GPU wheels).
- **Suggested published table:** Minimum: 4-core x86_64/arm64, 8 GB RAM (2B model, CPU, minutes/letter) · Recommended: 16 GB or any Apple Silicon Mac or ≥6 GB VRAM NVIDIA (4B model, seconds–tens-of-seconds/letter) · ~1–2 GB disk + models (≈4 GB) + archive growth. This is right in line with Immich's 6–8 GB norm, so it won't scare the audience.

## Prioritized launch checklist

### Must-have (blocks a credible "install this yourself" launch)

1. **LICENSE file — AGPL-3.0** (recommended, §1) + SPDX headers; decide DCO (recommended) and note it in CONTRIBUTING. *Without this the repo is legally not open source at all.*
2. **Adopter-facing README rewrite**: pitch, screenshots (web UI exists today), quickstart, honest hardware table (§5), "author runs it on an 8 GB M1 mini" as social proof; move plan.md/CLAUDE.md links to a "development" section.
3. **Linux path**: make PaddleOCR the primary engine off-macOS (abstraction already exists in `spike/ocr_engines.py`), pin a tested paddle/paddleocr combo, CI job on ubuntu-latest running the test suite.
4. **Docker Compose quickstart**: app container (+ published GHCR image via CI) with Ollama as a compose service *or* external `OLLAMA_URL` (mandatory escape hatch for Mac hosts, §2); volumes for `data/`; internal-only network for the worker as the egress-lockdown feature.
5. **Config + update story documented**: env-var reference (already half-exists in CLAUDE.md "How to run it"), backup = copy the data dir + SQLite file, "how do I update" section, and a DB schema-migration mechanism (or an explicit pre-1.0 "may require re-ingest" disclaimer).
6. **v0.x GitHub Releases + tags** with changelog and a pre-1.0 stability banner.
7. **SECURITY.md** + the security-model paragraph front-and-center (overlay-only, no cloud, egress lockdown) — it's the product's main differentiator.
8. **Rename decision executed before announcing** (§4 — facts gathered; PyPI/GitHub/domain windows close after a launch, and "my-flopy" collides culturally with USGS FloPy).
9. **Scrub personal-info/owner-specific content** from adopter-facing docs (RUNBOOK, deploy/ launchd defaults, hard-coded LAN assumptions) — CLAUDE.md's own "repo is public" rule.

### Nice-to-have (fast follows)

10. CONTRIBUTING.md + Contributor Covenant CoC + issue/PR templates + GitHub Discussions enabled.
11. Docs site (mkdocs-material) once README overflows; FAQ + troubleshooting.
12. Live demo instance or a Papra-style client-side demo; short capture-to-search GIF.
13. Discord (or Matrix) once there are actual users — not before.
14. arm64 Docker image (Pi 5 / ARM servers; CPU-only Paddle is fine there).
15. `install.sh` convenience script à la Paperless-ngx.
16. awesome-selfhosted + r/selfhosted / selfh.st listing after 1–9 are done (awesome-selfhosted requires an OSI license — another reason AGPL beats BSL/FSL here).
17. Keep future SaaS control-plane code (billing/multi-tenant) in a separate private repo from day one (§1).

Key sources: [Immich licensing discussion](https://github.com/immich-app/immich/discussions/11186) · [Immich joins FUTO](https://immich.app/blog/immich-joins-futo) · [Papra](https://github.com/papra-hq/papra) + [pricing](https://papra.app/en/pricing/) · [Plausible CE](https://plausible.io/blog/community-edition) · [Paperless-ngx setup docs](https://docs.paperless-ngx.com/setup/) · [FINOS CLA/DCO](https://osr.finos.org/docs/bok/artifacts/clas-and-dcos) · [FSL](https://fsl.software/) · [PaddleOCR ARM64 discussion](https://github.com/PaddlePaddle/PaddleOCR/discussions/17328) · [sqlite-vec install docs](https://alexgarcia.xyz/sqlite-vec/installation.html) · [Ollama Docker docs](https://docs.ollama.com/docker) · [Ollama qwen3-vl library](https://ollama.com/library/qwen3-vl) · [Immich requirements](https://docs.immich.app/install/requirements/) · [PaddleOCR 3.0 technical report](https://arxiv.org/html/2507.05595v1) · [flopy on PyPI](https://pypi.org/project/flopy/).