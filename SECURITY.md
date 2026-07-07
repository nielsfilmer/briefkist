# Security policy

Briefkist's whole point is that your mail never leaves hardware you control.
The security model (private-overlay-only access, per-device tokens, egress
lockdown on the processing path, no third parties) is described in
[plan.md](plan.md) §5.1.

## Reporting a vulnerability

Please report vulnerabilities privately via **GitHub Security Advisories**
("Report a vulnerability" on this repo; enabled at public launch) — not in
public issues.
You'll get an acknowledgment within 72 hours. Coordinated disclosure
appreciated; we'll credit you unless you prefer otherwise.

## Scope notes

- The server assumes a **trusted private network / overlay** between your
  devices and your box; it deliberately refuses wildcard binds.
- The processing pipeline is designed to run with **no network egress**;
  anything that makes it phone out is a vulnerability — report it.
