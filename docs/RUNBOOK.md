# my-flopy runbook (v1 — Phase 1 thin slice on the Mac mini)

The production host is the owner's always-on 8 GB M1 Mac mini. Everything runs
as native processes (plan.md decision log #3). Two services:

| Service | How it runs | Check |
|---|---|---|
| **Ollama** (VLM + embeddings) | `brew services start ollama` (login item, binds 127.0.0.1:11434) | `ollama ps` |
| **my-flopy server** | launchd agent `nl.eviloverlord.flopy` (see below) | `curl http://<LAN-IP>:8484/api/status` |

Models in use (already pulled): `qwen3-vl:4b-instruct` (extractor — always the
`-instruct` tag, see plan decision log #8), `qwen3-vl:2b-instruct` (speed
fallback, `FLOPY_VLM_MODEL` env), `bge-m3` (embeddings).

## Install / update the server service

```bash
bash deploy/install.sh            # binds this Mac's primary LAN IP
bash deploy/install.sh 192.168.1.76   # or an explicit interface address
```

Re-run after `git pull` (it re-substitutes paths and restarts). The server
refuses wildcard binds by design (§5.1) — always a specific address.

- Logs: `~/Library/Logs/flopy/server.log`
- Restart: `launchctl kickstart -k gui/$(id -u)/nl.eviloverlord.flopy`
- Remove: `launchctl bootout gui/$(id -u)/nl.eviloverlord.flopy`

## Phone setup (first time, ~2 minutes)

1. On the mini: `uv run python -m server.tokens_cli add "niels-iphone"` → copy
   the printed token (shown once).
2. On the phone (same Wi-Fi): open `http://<mini-LAN-IP>:8484`, tap **⚙︎**,
   paste the token, Save.
3. Share-sheet → **Add to Home Screen** for an app-like experience.
4. Lost/stolen phone: `uv run python -m server.tokens_cli revoke "niels-iphone"`
   — takes effect immediately.

Camera note: the capture button uses the file-picker→camera hop (works over
plain LAN HTTP). A live in-page camera preview needs HTTPS and is planned with
the Tailscale cert in Phase 3 (plan.md §10).

## Daily operation

- Capture: photograph → upload → processing is async (~20–30 s/page on this
  host); the Recent uploads list live-updates and flags **needs review**.
- Review queue: Archive tab → tick **needs review**. Correct any field inline;
  corrections are audited (they feed the §12 improvement loop) and immediately
  searchable.
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
  lockdown + formal airplane-mode test are the Phase 3 gate (issues #14).
- Latency ~20–30 s/page vs the 15 s KPI (issue #13).
- Semantic-search relevance cutoff untuned until real letters exist (#20).
