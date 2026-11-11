# Test Watchlist — Fedora, homelab and local AI

**Created:** 2026-11-07  
**Scope:** cross-project evaluation queue, not a deployment queue  
**Maintained in:** `wojko6/fedora-workstation-setup`  
**Canonical operational state:** [`PROJECT-STATUS.md`](../PROJECT-STATUS.md) and project-specific evidence

This document is the **single intake list for new applications, utilities,
experimental integrations and models worth trying** across our Fedora/KDE
desktop, ASUS Edge Gateway infrastructure and local AI assistant. It links to
existing project issues rather than copying their implementation checklists.
It does **not** replace [`ROADMAP.md`](../ROADMAP.md), accepted configuration
files, or the ASUS repository's roadmap, and creates no new GitHub issues.

**2026-11-10 state:** the physical workstation now runs **Fedora 45 / KDE Plasma 6.8.2 / Wayland** with **NVIDIA 620.70.06 Open**. The former Fedora 44 / NVIDIA 610.57.04 versionlocks are a historical 2026-11-07 checkpoint; the last fully accepted **reproducible** baseline remains Fedora 44 / GNOME 50.5 pending target clean-room verification. See [migration worklog](WORKLOG-2026-11-10.md). Items below
are **not installed, tested or accepted merely because they appear here**.

## How to read and update this list

Allowed statuses (kept in Polish for easy review):

- **DO SPRAWDZENIA** — only researched or proposed; no accepted test result.
- **W TRAKCIE TESTÓW** — a controlled lab test has begun; cite evidence.
- **ZAAKCEPTOWANE** — explicit acceptance with verified scope, version, results
  and rollback; this does not itself promote the workstation baseline.
- **ODRZUCONE** — rejected after review, with recorded reasons.

Priorities: **P1** = near-term and useful; **P2** = worthwhile when capacity
exists; **P3** = curiosity, optional comparison or blocked by a missing need.
Priority is **not permission to install**.

For each candidate, keep a minimal entry with: stable identifier; product/
project link; existing issue (if one exists); target use case; current status;
priority; minimal first test; safety/rollback conditions; and next decision.
When a test really starts, add a dated evidence link (existing issue comment,
worklog or lab report). Do not change a status based only on an upstream
release, benchmark, idea, or theoretical compatibility.

## Active evaluation queue

| ID | Candidate / upstream | Use case | Priority | Status | Existing tracking |
| --- | --- | --- | --- | --- | --- |
| MOB-01 | [NectarLink](https://github.com/thtbee/nectarlink) | Fedora KDE ↔ Poco F8 Pro; notifications, clipboard, transfer, mirroring and possible local-AI alerts | **P1** | **DO SPRAWDZENIA** | Watchlist only; no local issue |
| AI-01 | Read-only [MCP for ASUS Edge Gateway](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/85) | Restricted status checks for the local AI assistant | **P1** | **DO SPRAWDZENIA** | ASUS [#85](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/85) |
| AI-02 | Local documentation retrieval / RAG | Let Qwen cite previous Fedora, router, agent and macOS experiments rather than repeat them | **P1** | **DO SPRAWDZENIA** | Watchlist only; design candidate |
| OBS-01 | [Unbound Exporter + Grafana](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/259) | Resolver metrics without changing production DNS routing | **P2** | **DO SPRAWDZENIA** | ASUS [#259](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/259) |
| OBS-02 | [Homelab Control Center](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/303) | A read-only operational dashboard on Fedora | **P2** | **DO SPRAWDZENIA** | ASUS [#303](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/303) |
| OBS-03 | [Homelab Black Box](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/304) | Join logs, metrics and time windows into evidence-based incident timelines | **P2** | **DO SPRAWDZENIA** | ASUS [#304](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/304) |
| KDE-01 | [TMOG Task Manager OG](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/262) | Compare an alternative task manager on KDE Wayland | **P2** | **DO SPRAWDZENIA** | ASUS [#262](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/262) |
| OBS-04 | [ModSyslogUI](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/89) | Lightweight local syslog viewing/filtering versus current Grafana/Loki | **P2** | **DO SPRAWDZENIA** | ASUS [#89](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/89) |
| AI-03 | [Qwen3.5-9B community Heretic variant](https://huggingface.co/xtools-at/DeepSeek-V4-Pro-Qwen3.5-9B-UNCENSORED-heretic) | Optional offline comparison against the working Qwen3.5:4B | **P3** | **DO SPRAWDZENIA** | No model replacement planned |
| KDE-02 | [Mac Tahoe Liquid KDE upstream updates](https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde/releases) | Compatibility/translation-regression test before any theme/widget update | **P3** | **DO SPRAWDZENIA** | Fedora [#12](https://github.com/wojko6/fedora-workstation-setup/issues/12); [B291/B292](../localization/kde-tahoe/README.md) |

The table records **candidate evaluations** only. The local assistant already
uses Qwen3.5:4B, and no accuracy problem requiring a model swap has been
reported. KDE Connect/GSConnect and the current monitoring/backup components
remain in place until a separate decision is accepted.

## Minimal test plans and guardrails

### MOB-01 — NectarLink (P1)

1. Review the stable package, source provenance, permissions and current Linux
   limitations. Compare its benefits against KDE Connect/GSConnect and scrcpy.
2. Prefer a **disposable VM or a confined, reversible app-only trial** before
   any host integration. Do not execute the one-line `curl | sh` installer on
   the workstation: its default path can change firewalld, `udev` access and
   `v4l2loopback` kernel modules.
3. Start with basic pairing/notifications or file transfer only after review.
   Keep Android Accessibility, wireless ADB/`Elevated`, SMS, remote command
   execution, automatic photo sync and auto-update **off** in the first test.
4. Confirm KDE Wayland behavior, Tailscale routing and possible interaction
   with the carefully managed `workstation-kdeconnect` / Tailscale firewall
   boundaries. No blanket firewall opening or input-device permission grants.
5. Note: upstream states that Linux identity keys and clipboard data are
   protected by file permissions, not platform at-rest encryption. The Android
   client has broad optional privileges. Evaluate data exposure explicitly.
6. Record the exact release, packaging method, tests, observed effects,
   cleanup/rollback and decision before any production deployment.

### AI-01 — read-only MCP control plane (P1)

Begin with **mocked status endpoints only**. Next permit a tiny, audited
read-only command allowlist, pinned SSH host key and dedicated identity;
reject arbitrary shell, raw command arguments, config writes and production
router access until explicitly reviewed. Refer to the requirements in
[ASUS #85](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/85).
The AI model itself has no authority to approve mutating operations.

### AI-02 — local documentation retrieval (P1)

Start with a sanitized **read-only index** of selected Markdown reports and
issue summaries. Test source citations, stale version awareness and unknown
answer handling on historical NVIDIA/KDE, DNS Guard and macOS troubleshooting
questions. Do not ingest private keys, tokens, full personal logs or recovery
secrets. No repo write access or autonomous command execution.

### OBS-01 / OBS-02 / OBS-03 / OBS-04 (P2)

Prototype outside the production data path: query existing metrics/logs
read-only, or use recorded fixtures. Measure usefulness against current
Loki, Grafana, VictoriaMetrics and RouterCloud. No resolver replacement,
agent restart, port exposure, extra persistence, or alert spamming during
comparison. Keep the existing issues authoritative for scope.

### KDE-01 — alternative task manager (P2)

Review compatibility with Plasma 6.8.x and Wayland; try only a standalone
isolated candidate first. **Never replace** the running task manager or
overwrite panel configuration as the first test. Save UI screenshots and
record a restoration path before any opt-in panel experiment.

### AI-03 — optional larger model (P3)

Do not replace Qwen3.5:4B. If ever useful, evaluate an isolated, resource-
limited Q3/Q4 9B variant with no tools/network, using identical Polish
technical prompts, hallucination checks, latency and RAM/VRAM observations.
Treat upstream benchmarks and the `UNCENSORED` label as unverified
suitability claims, not as evidence of safety or accuracy improvements.

### KDE-02 — Tahoe theme update (P3)

Review upstream diff and localization domains, validate in a separate test
user/VM, then retest the archived [B291/B292](../localization/kde-tahoe/README.md)
Polish catalogs. Protect the working panel, KWin effects, global menu, launcher,
NVIDIA configuration and current desktop. Upstream availability alone is not
a reason to upgrade.

## Research sources and historical references

- [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted):
  an **idea source**, not one application to deploy. Add a specific candidate
  to the table only after its function and safety boundary are clear.
- [DUFS / RouterCloud UI research, ASUS #157](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/157):
  **closed** existing issue, retained for context. Do not silently reopen it
  or treat it as an active pending task.
- Fedora [#17](https://github.com/wojko6/fedora-workstation-setup/issues/17)
  remains the workstation execution umbrella; ASUS
  [#82](https://github.com/wojko6/Advanced-ASUS-Edge-Gateway-ZTNA-Infrastructure/issues/82)
  remains its infrastructure roadmap. These are not duplicated here.

## Decision, test and promotion rules

1. **Intake:** add a row with an upstream link, real use case, priority,
   caveat and existing issue if applicable. Check for duplicates first.
2. **Preflight:** check current OS, application release, architecture,
   package provenance, privileges, network bindings, disk writes and
   compatibility with NVIDIA/KDE, SELinux, firewalld and Tailscale.
3. **Safe trial:** use read-only checks, fixtures, VM or a constrained
   non-production user session first. A new service, package installation,
   system permission, Android privilege, or device pairing requires
   **explicit operator approval**.
4. **Evidence:** capture version, scope, observable result, exit status
   and rollback. Avoid any secrets, personal data or sensitive logs in public
   commits.
5. **Outcome:** update the status and decision with a dated evidence
   reference. `ZAAKCEPTOWANE` means the **bounded trial** was accepted;
   production promotion requires its own restore/security/physical gate.
6. **Maintenance:** review periodically when evaluating new software,
   but do not auto-install, auto-poll or create notifications just because
   an item is listed. Do not create a new GitHub issue unless detailed
   implementation tracking is genuinely needed and explicitly authorized.

**As of 2026-11-07: all entries in this watchlist are untested candidates
in the narrow scope described here. No workstation, phone or router changes
are authorized or claimed.**
