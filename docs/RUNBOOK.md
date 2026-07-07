# Briefkist runbook (v1 — Phase 1 thin slice on the Mac mini)

The production host is the owner's always-on 8 GB M1 Mac mini. Everything runs
as native processes (plan.md decision log #3). Two services:

| Service | How it runs | Check |
|---|---|---|
| **Ollama** (VLM + embeddings) | `brew services start ollama` (login item, binds 127.0.0.1:11434) | `ollama ps` |
| **Briefkist server** | launchd agent `app.briefkist.server` (see below) | `curl -i http://<LAN-IP>:8484/api/status` — **a 401 also means alive** (auth is on every endpoint; add `-H "Authorization: Bearer <token>"` for the real payload) |

Models in use (already pulled): `qwen3-vl:4b-instruct` (extractor — always the
`-instruct` tag, see plan decision log #8), `qwen3-vl:2b-instruct` (speed
fallback, `FLOPY_VLM_MODEL` env), `bge-m3` (embeddings).

## Install / update the server service

```bash
bash deploy/install.sh            # binds this Mac's primary LAN IP
bash deploy/install.sh 192.168.1.76   # or an explicit interface address
```

Re-run after `git pull` (it re-substitutes paths and restarts). **Upgrading a
pre-rename install:** install.sh now boots out the old
`nl.eviloverlord.flopy` agent automatically; if you installed the service
before the Briefkist rename and don't re-run install.sh, unload it once by hand:
`launchctl bootout gui/$(id -u)/nl.eviloverlord.flopy && rm
~/Library/LaunchAgents/nl.eviloverlord.flopy.plist` (removing the plist
matters — RunAtLoad would re-bootstrap it at next login). The server
refuses wildcard binds by design (§5.1) — always a specific address.

- Logs: `~/Library/Logs/briefkist/server.log`
- Restart: `launchctl kickstart -k gui/$(id -u)/app.briefkist.server`
- Remove: `launchctl bootout gui/$(id -u)/app.briefkist.server && rm ~/Library/LaunchAgents/app.briefkist.server.plist`

Troubleshooting: **repeating bind errors in the log** usually mean the mini's
LAN IP changed (DHCP) — re-run `bash deploy/install.sh` to pick up the new
address, and give the mini a **DHCP reservation / static IP** in the router so
it stops happening (launchd retries every 15 s by design, so it recovers by
itself once the address is right).

## Docker (Linux)

The native macOS install above stays the primary, best-tested path — it is
what the author runs, and it gets Apple Vision OCR plus Metal-accelerated
Ollama. For Linux servers/NAS boxes there is a Docker Compose stack
(`docker-compose.yml` at the repo root; image published as
`ghcr.io/nielsfilmer/briefkist`):

```bash
docker compose pull            # or build locally: docker compose build
# One-time model pull (the ollama service has no internet route by design —
# follow the numbered steps in docker-compose.yml's header comment), then:
docker compose up -d
docker compose exec briefkist python -m server.tokens_cli add "my-phone"
```

Notes:

- **OCR in the container is PaddleOCR** (Apple Vision doesn't exist off
  macOS; engine selection is automatic per platform, override with
  `FLOPY_OCR_ENGINE`). The PP-OCRv5 models are baked into the image, so the
  running container needs no network beyond Ollama.
- **Egress lockdown by topology**: Ollama sits on an internal-only Docker
  network with zero internet route; only Briefkist's port is published.
- **Exposure = the port mapping.** The compose file publishes on `127.0.0.1`
  by default — change it to your LAN or Tailscale address (§5.1: never a bare
  `"8484:8484"`, that's every interface).
- **Backup** = the `briefkist-data` volume (same contents as the native data
  dir).
- **Mac hosts: keep Ollama native** (Docker gets no Metal) — use the
  external-Ollama variant commented at the bottom of `docker-compose.yml`.

## Phone setup (first time, ~2 minutes)

**With the native apps (preferred):**

1. **Mint the desktop's own token once, via the CLI** (the deployed service
   listens on the LAN address only, so there is no loopback bootstrap to
   lean on). On the mini, from the repo checkout directory (or with the same
   `FLOPY_DATA_DIR` the service uses):
   `uv run python -m server.tokens_cli add "mini-desktop"` → copy the token.
2. Run the desktop app (`cd app && flutter run -d macos`, or a built copy) →
   Settings → Connection: enter `http://<mini-LAN-IP>:8484` + that token,
   Save. (The address must be the LAN IP — the pairing card refuses to mint
   codes for a loopback address, since no other device could reach it.)
3. Settings → **Pair a device**: type a name for the phone (e.g.
   "niels-iphone") → **Create pairing code** → a QR appears (or "Show token
   instead"). The token is shown exactly once.
4. On the iPhone: open the Briefkist app → onboarding → **Scan the code**
   (or paste the token in settings). Done — capture away.
5. Lost/stolen phone: desktop app → Settings → Paired devices → **Revoke**
   (or `uv run python -m server.tokens_cli revoke "niels-iphone"` from the
   checkout dir / with the service's `FLOPY_DATA_DIR`) — takes effect
   immediately.

**Web fallback (no app install):**

1. On the mini, **from the repo checkout directory** (the tokens file lives in
   the data dir, which defaults to `<repo>/data/archive` — running the command
   elsewhere writes a tokens file the service never reads):
   `uv run python -m server.tokens_cli add "my-iphone"` → copy the printed
   token (shown once). If you set `FLOPY_DATA_DIR`, export the same value for
   this command.
2. On the phone (same Wi-Fi): open `http://<mini-LAN-IP>:8484`, tap **⚙︎**,
   paste the token, Save. Share-sheet → **Add to Home Screen**.

Camera note: the capture button uses the file-picker→camera hop (works over
plain LAN HTTP). A live in-page camera preview needs HTTPS and is planned with
the Tailscale cert in Phase 3 (plan.md §10).

## Daily operation

- Capture: photograph → upload → processing is async (~20–30 s/page on this
  host); the Recent uploads list live-updates until the letter is filed.
- Every letter files directly with a category, summary and curated keywords
  (no review queue — decision log v0.4). Correct any field inline in the
  detail view; corrections are audited (they feed the §12 improvement loop)
  and immediately searchable.
- Failed ingests show a **✕ remove** button (only failed documents can be
  deleted — archive deletion/retention is deliberately out of v1 scope).

## Backup

Everything lives under the data dir (default `data/archive/`): one SQLite file
(`flopy.db` + WAL) and the image folders. Copy that folder = full backup.
Automated encrypted backups (restic/age) are Phase 3 scope — until then, a
periodic manual copy to an external disk is the interim measure.

## Real-letter benchmark (the definitive Phase 0 numbers)

Drop phone photos into `data/testset-real/images/` (+ optional truth JSON —
see `testset/README.md`), then:

```bash
uv run python -m spike.benchmark --set data/testset-real --out docs/phase0-real
```

## Model / capacity knobs

- Speed over accuracy: `FLOPY_VLM_MODEL=qwen3-vl:2b-instruct` in the plist,
  re-run install.sh (latency work tracked in issue #13).
- Future 32 GB mini: pull `qwen3-vl:8b-instruct`, set the env, restart —
  everything else is unchanged (plan decision log #1).
- Never raise the extractor's `num_ctx` above 4096 on 8 GB hardware
  (decision log #8: KV spill collapses generation ~10×).

## Known limitations (v1, tracked)

- Remote ("on the road") access not yet wired: Tailscale + host-level egress
  lockdown + formal airplane-mode test are the Phase 3 gate (issue #14).
- Latency ~20–30 s/page vs the 15 s KPI (issue #13).
- Semantic-search relevance cutoff untuned until real letters exist (#20).
