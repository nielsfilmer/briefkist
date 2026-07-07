# Research: Hosted-privacy architecture & EU hosting

*Commissioned for the Productization phase (tracker #44); researched 2026-07-06/07 by a web-research agent; preserved verbatim as decision input. Prices/availability are point-in-time.*

---

All research gathered. Here is the report.

---

# Hosted my-flopy: privacy-honest architecture research

**Scope:** how to offer a rented, ready-made hosted my-flopy server (monthly fee) while keeping the privacy promise technically honest. Constraint that shapes everything: **the pipeline must see plaintext images in RAM** (OCR + VLM), so true E2EE/zero-knowledge is impossible for the processing step. The honest ceiling is: *plaintext exists transiently in memory during ingestion; everything at rest is under a key only the customer holds; no third party is ever in the data path.*

---

## 1. The three architecture patterns

### Pattern A — Per-tenant VM + customer-held full-disk-encryption key

One VM per customer; root/data volume is LUKS/dm-crypt-encrypted; the passphrase is held by the **customer** and supplied at unlock time (boot, or volume-mount).

- **Mechanics are well-trodden:** remote LUKS unlock via Dropbear SSH in initrd is standard practice ([nixCraft guide](https://www.cyberciti.biz/security/how-to-unlock-luks-using-dropbear-ssh-keys-remotely-in-linux/), [Swiss Made Host walkthrough](https://swissmade.host/en/blog/unlocking-a-luks-fully-encrypted-drive-and-booting-into-the-os-via-dropbear-ssh)); tools like [luksrku](https://github.com/johndoe31415/luksrku) automate unlock over TLS. In-place LUKS2 encryption of a stock VPS is documented for Hetzner-style hosts ([onidel guide](https://onidel.com/blog/encrypt-ubuntu-vps-luks2)). For a consumer product you'd wrap this in a **web unlock flow** ("enter your archive passphrase to bring your server online") rather than SSH.
- **Honest limits:** the hypervisor operator (you + Hetzner) can snapshot RAM of a running VM; the key is in kernel memory the whole time the VM is up. LUKS protects against disk theft, provider disk recycling, and *you* reading customer data while the VM is locked — not against a live-host attacker. This is exactly the caveat Nextcloud publishes for its own server-side encryption: keys "will be present in memory of the server... and could be retrieved by a determined attacker"; it protects data **at rest only** ([Nextcloud SSE docs](https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/encryption_configuration.html), [encryption whitepaper](https://nextcloud.com/encryption/)).
- **UX cost:** customer must re-enter the passphrase after any reboot/maintenance; a forgotten passphrase = total data loss (which is also the honest selling point).

### Pattern B — Confidential computing (AMD SEV-SNP / Intel TDX)

Hardware-encrypted VM memory + remote attestation, so even the host operator can't read RAM.

- **Availability at the budget-EU providers you'd actually use is poor.** Hetzner offers no SEV-SNP/TDX, no vTPM, no secure boot on cloud VMs ([HN discussion](https://news.ycombinator.com/item?id=45615648)); their AX dedicated line is Ryzen (no SEV — SEV is EPYC-only). Scaleway lists no confidential-computing product ([instance lineup](https://www.scaleway.com/en/virtual-instances/)). OVHcloud sells "confidential computing" only on **bare metal** (Intel SGX on Advance line, AMD Infinity Guard/SEV on EPYC Scale/Advance) at **$343–531/month per server**, with no managed attestation story ([OVH confidential computing](https://us.ovhcloud.com/bare-metal/uc-confidential-computing/)). The EU provider that genuinely productizes it is **STACKIT** (with Edgeless Systems' Confidential Kubernetes) ([EU provider comparison](https://www.softwareseni.com/eu-native-cloud-providers-compared-hetzner-ovhcloud-scaleway-and-t-systems/)); otherwise it's Azure/GCP/AWS ([Azure CVM options](https://learn.microsoft.com/en-us/azure/confidential-computing/virtual-machine-options), [GCP Confidential VM](https://docs.cloud.google.com/confidential-computing/confidential-vm/docs/confidential-vm-overview)) — which contradicts the EU-sovereignty story.
- **Attestation is the real cost.** The privacy value only materializes if the *customer* can verify the attestation; otherwise it's "trust us, the CPU says so." Edgeless Systems' own writing shows attestation chains across even a two-component system get "almost impossible to verify and reason about" without dedicated tooling ([The three levels of confidential computing](https://www.edgeless.systems/blog/the-three-levels-of-confidential-computing)). For a solo operator whose customers are consumers archiving letters, nobody will verify a SEV-SNP attestation report. Confidential **GPU** inference (needed for the VLM) is bleeding-edge and hyperscaler-only (H100-class, Azure) ([Azure confidential GPUs](https://thomasvanlaere.com/posts/2025/03/azure-confidential-computing-confidential-gpus-and-ai/)).
- **Verdict: marketing overkill for a solo v1.** It protects against *your hosting provider*, not against *you* — and you are the party the customer must trust anyway, since you build the image the enclave runs. Revisit if the product grows and STACKIT-style Confidential Kubernetes becomes turnkey.

### Pattern C — Application-level envelope encryption (customer-passphrase-derived key)

Data encrypted with per-document DEKs wrapped by a KEK derived from the customer's passphrase (Argon2id/PBKDF2); server holds the unwrapped KEK **in memory only while a session is active / during ingestion**, never on disk.

- **Prior art is solid.** Keeper derives keys client-side with PBKDF2 and the server stores only ciphertext ([Keeper encryption model](https://docs.keeper.io/enterprise-guide/keeper-encryption-model)); IronCore's SaaS Shield productizes exactly the "vendor discards the DEK from memory, persists only ciphertext, optional short-lived key leasing" pattern ([IronCore SaaS Shield FAQ](https://ironcorelabs.com/docs/saas-shield/faq/)); per-user-key-in-Postgres writeups cover the small-SaaS version ([marcopeg.com](https://marcopeg.com/per-user-encryption-with-postgres/)).
- **The closest analog to my-flopy's ingest problem is Proton's incoming external mail:** plaintext necessarily transits the server, is processed, then immediately encrypted to the user's key so it becomes zero-access *at rest* — and Proton says so plainly: "our servers can read that email" on arrival ([Proton zero-access page](https://proton.me/security/zero-access-encryption)). my-flopy ingest is the same shape: photo arrives → OCR/VLM in RAM → metadata + image encrypted under the customer's key → plaintext discarded.
- **Design note for this workload:** embeddings and FTS indexes are derived plaintext. Either encrypt the whole SQLite file under the session key (search only works during an unlocked session — acceptable for a personal archive), or be honest that the index is only disk-encrypted (Pattern A level). The former is stronger and cheap at personal-archive scale.

---

## 2. Honest claims: wording that survives scrutiny

**What comparable products actually say:**

| Product | Claim | Honesty mechanics |
|---|---|---|
| Proton | "zero-access encryption — only you can access it" **at rest**, with explicit carve-out that incoming external mail is readable on arrival | [proton.me/security/zero-access-encryption](https://proton.me/security/zero-access-encryption) |
| CryptPad | "zero knowledge = we make ourselves blind to your content"; notably humble: "we cannot easily prove that we've never collected any data but we can prove we're not doing it systematically" | [CryptPad blog](https://blog.cryptpad.org/2017/03/24/What-is-Zero-Knowledge/) |
| Standard Notes | "end-to-end encrypted... we can't read it, and we can't sell it" — true because encryption is fully client-side | [standardnotes.com](https://standardnotes.com/) |
| Nextcloud (SSE) | explicitly does **not** claim zero-knowledge: keys are in server memory during sessions; protects at-rest only; admin compromise defeats it | [SSE docs](https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/encryption_configuration.html) |

**Where overclaiming got punished:** the canonical case is **FTC v. Zoom (2020)** — Zoom advertised "end-to-end, 256-bit encryption" while its servers held the meeting keys; the FTC called this deceptive, and the settlement imposed a 20-year security-program + biennial-audit regime ([FTC press release](https://www.ftc.gov/news-events/news/press-releases/2020/11/ftc-requires-zoom-enhance-its-security-practices-part-settlement), [FTC business blog](https://www.ftc.gov/business-guidance/blog/2020/11/zooming-zooms-unfair-deceptive-security-practices-more-about-ftc-settlement)). The EU analog is unfair-commercial-practices / GDPR Art. 5(1)(a) transparency; the lesson is identical: **never say "end-to-end" or "zero-knowledge" if your server ever holds a key that decrypts customer content.**

**Honest claim per pattern:**

- **Pattern A:** "Your archive is stored on a server dedicated to you, fully disk-encrypted with a passphrase **only you hold**. When your server is locked, no one — including us — can read your data. While it runs, our administrators could technically access it; we contractually and technically minimize that." ❌ Not: "zero-knowledge", "we cannot access your data".
- **Pattern B:** "Even our hosting provider cannot read your server's memory (hardware-attested confidential VM)." Honest **only if** you publish attestation evidence and admit you author the software inside the enclave. Strongest claim, least verifiable by your actual audience.
- **Pattern C:** "Every document is encrypted with a key derived from a passphrase only you know. We store only ciphertext. During the seconds a letter is being scanned and understood, it exists unencrypted in your private server's memory — that's the only moment; nothing unencrypted ever touches disk, and no third party is ever in the path." This is Proton's incoming-mail framing, and it's the most honest strong claim available for this workload.

---

## 3. EU hosting shortlist + inference economics

Key workload insight first: **snail-mail archiving is async and low-throughput** (a few letters/week per customer). Latency tolerance is "minutes per letter", not "seconds" — which makes CPU inference viable and changes the economics completely.

| Option | Shape | Price (excl. VAT) | Fit |
|---|---|---|---|
| **Hetzner CAX31** (ARM Ampere, 8 vCPU / 16 GB) | per-tenant VM | ~€12.49 → **€31.49/mo** after Hetzner's June 2026 increases ([Hetzner price adjustment](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/), [Northflank breakdown](https://northflank.com/blog/hetzner-cloud-server-price-increases)) | qwen3-vl:4b Q4 (~4–5 GB) + PaddleOCR fit; expect roughly 3–6 tok/s for a 3–4B model on this class of CPU ([Better Stack Hetzner review](https://betterstack.com/community/guides/web-servers/hetzner-cloud-review/)) → ~2–5 min/letter incl. vision prefill. Fine for async ingest. |
| **Hetzner CAX41** (16 vCPU / 32 GB) | per-tenant VM | ~€24.49 → **€40.99/mo** | Halves latency; overkill for v1. |
| **Hetzner dedicated (e.g. AX-line ~€50–60/mo)** | one box, 4–8 tenant VMs | ~**€8–15/tenant/mo** | Best unit economics: per-tenant LUKS-encrypted VMs + a shared sequential inference queue. Caveat below. |
| **Hetzner GEX44** (RTX 4000 SFF Ada 20 GB, dedicated) | shared GPU inference worker | **€184/mo + €79 setup** ([Hetzner GEX44](https://www.hetzner.com/dedicated-rootserver/gex44/), [whtop listing](https://www.whtop.com/plans/hetzner.com/128304)) | Runs 4B VLM at interactive speed; amortized over 20+ tenants it's ~€9/tenant. But plaintext from all tenants transits one box — weakens the single-tenant story (still first-party-only; disclose it). |
| **Scaleway L4** (24 GB GPU) | GPU instance | €0.79/h ≈ **€570/mo** ([Scaleway L4](https://www.scaleway.com/en/l4-gpu-instance/)) | Not viable per-tenant; only as a shared worker, and GEX44 is 3× cheaper. |
| **OVH confidential bare metal** | Pattern B | **$343–531/mo/server** ([OVH](https://us.ovhcloud.com/bare-metal/uc-confidential-computing/)) | Only if Pattern B is pursued; it shouldn't be for v1. |

**Cheapest workable v1 shape:** per-tenant CAX21/CAX31 ARM VM (or per-tenant VMs on one dedicated box), CPU-only Ollama, sequential worker — exactly the architecture my-flopy already has on the 8 GB M1 mini. No GPU needed at snail-mail volumes.

---

## 4. Who does "managed self-host" already — and Paperless-ngx price anchors

- **PikaPods** — the closest comparable. Paperless-ngx: **$4.9/mo** at default resources ([pikapods.com/apps](https://www.pikapods.com/apps)); pay-per-resource, hourly-billed, $5 welcome credit; EU-hosted with GDPR pages. Privacy claim is "your data, your pod" isolation — no customer-held-key story; they can access everything.
- **Elestio** — managed Paperless-ngx **from $16/mo** on a dedicated VM (choice of Hetzner/Scaleway/Netcup...), automated backups/SSL/updates; leans on ISO 27001/SOC2/GDPR compliance rather than cryptographic claims ([Elestio Paperless pricing](https://elest.io/open-source/paperless-ngx/resources/plans-and-pricing), [Elestio pricing](https://elest.io/pricing)).
- **Cloud68** — quote-based managed hosting of ~23 OSS apps on dedicated servers in Germany; positioning is ethics/control ("YOU should have more control and privacy"), not cryptography; no public per-app price list ([cloud68.co](https://cloud68.co/), [managed hosting](https://cloud68.co/managed-hosting.html)).

**Implication:** the market anchor for "hosted document archive" is **$5–16/mo**, and none of the incumbents offer a customer-held key. A single-tenant CAX31 at €31.49 cost forces a **€19–29/mo privacy-premium price point** — justifiable only if the customer-held-key story is the headline differentiator. The shared-dedicated-box variant (€8–15/tenant cost) allows a €15–19/mo price while keeping per-tenant encrypted VMs.

---

## 5. GDPR essentials (solo operator, NL)

- **Role: you are a processor**, the customer is the controller of their letters' contents; hosting/SaaS providers touching personal data are processors "in principle" ([De Clercq on verwerkersovereenkomsten](https://declercq.com/en/blogs/ict-projecten-deel-9-de-verwerkersovereenkomst), [EDPB SME guide](https://www.edpb.europa.eu/sme/learn-the-basics/data-controller-or-data-processor_en)). Nuance: consumer customers archiving household mail enjoy the household exemption — **you don't**; your processing is commercial. You're also a *controller* for account/billing data.
- **Art. 28 DPA (verwerkersovereenkomst) is mandatory** — bake a standard DPA into the ToS covering: subject/duration/nature of processing, data types, security measures (Art. 32 — the encryption story slots in here beautifully), sub-processor consent (Hetzner is your sub-processor and must be listed, with Hetzner's own DPA signed), assistance duties, delete-or-return on termination ([business.gov.nl 10-step GDPR guide](https://business.gov.nl/running-your-business/legal-matters/how-to-make-your-business-gdpr-compliant/)).
- **Minimal viable compliance page:** privacy policy (controller-side data: account, billing, logs); DPA download; sub-processor list (Hetzner, DE/FI datacenter); records of processing (Art. 30 — required even for small entities when processing is non-occasional); breach-notification commitment (72h to the Autoriteit Persoonsgegevens where you're controller; "notify customer without undue delay" where processor); no DPO needed at this scale; no third-country transfers (all-EU stack — a genuine selling point).
- **The architecture is the compliance story:** customer-held keys + single-tenant + EU-only + no third-party processors in the data path makes Art. 32 "state of the art" trivially defensible.

---

## Comparison table

| | A: Per-tenant VM + customer-held FDE key | B: Confidential computing | C: App-level envelope encryption (+ A as baseline) |
|---|---|---|---|
| **Strongest honest claim** | "Encrypted at rest, key only you hold; **we could access while running**" | "Even the host can't read memory" (if attestation published) | "We store **only ciphertext**; plaintext exists only in RAM during ingestion/session" |
| **Overclaim risk** | Low if worded right; "zero-knowledge" would be false | High: claim collapses if customers can't verify attestation; you still author the code | Lowest gap between claim and reality; Proton-style precedent |
| **Cost / tenant / mo** | €12–41 (CAX21–41) or €8–15 on shared dedicated | €340+ (OVH bare metal) or hyperscaler CVMs (breaks EU-budget story) | Same as A + ~zero (software only) |
| **Complexity (solo op)** | Low-medium: LUKS + web unlock flow; reboot = customer re-unlock | High: attestation pipeline, niche providers, no confidential GPU in budget EU | Medium: key derivation, DEK wrapping, session key lifecycle, encrypted SQLite/index handling |
| **Latency** | CPU inference ~2–5 min/letter (fine, async) | Same or worse (no cheap GPU) | Same as A; ingest requires an unlocked session or queued-until-unlock |
| **Failure modes** | Forgotten passphrase = data loss (feature); RAM access by op | False sense of security; vendor lock | Same as A; plus crypto-implementation bugs |

---

## RECOMMENDATION (solo-operator v1)

**Build Pattern C layered on Pattern A, on Hetzner, CPU-only. Skip confidential computing.**

1. **Per-tenant VM** (Hetzner CAX21/CAX31 ARM, EU datacenter) running the existing my-flopy stack unchanged — the M1-mini sizing work transfers directly; CPU inference at 2–5 min/letter is fine for an async snail-mail pipeline. Start with per-tenant cloud VMs; move to per-tenant VMs on one dedicated box when >5 customers make the economics matter.
2. **LUKS full-disk encryption** on the data volume as the baseline (protects against provider-side disk exposure), **plus application-level envelope encryption**: per-document DEKs wrapped by an Argon2id-derived KEK from a passphrase only the customer holds; server keeps the KEK in RAM only while the customer's session is unlocked; photos queue encrypted-with-a-public-key until the next unlocked session if you want ingest-while-away (the Proton incoming-mail pattern). Encrypt the SQLite archive under the same envelope so FTS/embeddings aren't a plaintext side channel.
3. **Say exactly this, and no more:** "Single-tenant server in the EU. Everything stored is encrypted with a key derived from a passphrase only you hold — we keep only ciphertext and cannot read your archive. During the moments a letter is being scanned and understood, it is unencrypted in your private server's memory; that is the only moment, and no third party is ever involved." Never use "zero-knowledge" or "end-to-end encrypted" — that's the Zoom/FTC trap, and CryptPad/Proton show the humble framing sells fine.
4. **Price at €19–29/mo** as a privacy-premium product (vs PikaPods' $4.9 Paperless anchor); the customer-held key is the differentiator no incumbent offers.
5. **Compliance:** standard Art. 28 DPA in the ToS, Hetzner listed as sole sub-processor, Art. 30 register, one-page privacy policy. The architecture *is* the Art. 32 answer.
6. **Defer confidential computing** to a "v2 investigate" note: no budget-EU provider offers attestable confidential VMs today (Hetzner: none; Scaleway: none; OVH: $343+ bare metal), no confidential GPU outside hyperscalers, and your consumer audience can't consume attestation evidence anyway.

One design tension to decide early: a **shared GPU inference worker** (GEX44, €184/mo) would cut latency 10× and per-tenant cost at scale, but funnels all tenants' plaintext through one box — keep v1 fully single-tenant CPU so the marketing claim stays maximally clean, and revisit only with explicit disclosure.