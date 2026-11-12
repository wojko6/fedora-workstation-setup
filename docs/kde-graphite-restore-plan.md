# Fedora 45 KDE Graphite — reproducible restore design

**Date:** 2026-11-12  
**Status:** DESIGN / LAB ONLY — NOT AN ACCEPTED RESTORE BASELINE  
**Tracking:** [Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12), [Issue #17](https://github.com/wojko6/fedora-workstation-setup/issues/17)  
**Profile:** [kde/graphite/README.md](../kde/graphite/README.md)

## Decision and scope

Develop an opt-in, reproducible **Fedora 45 / KDE Plasma 6.8.2 / Wayland / Graphite** workstation profile in this repository, rather than starting an unrelated distribution fork. A distributable installer image may be considered only after a full clean-room rebuild and acceptance. The goal is reconstruction from reviewed manifests and artifact pins, not publication of a private laptop image.

The operating host is reported as Fedora 45 / KDE Plasma 6.8.2 / Wayland with NVIDIA 620.70.06 Open. **The last fully accepted reproducible baseline remains historical Fedora 44 / GNOME 50.5.** The two states must never be conflated. The current root `install.sh` and `scripts/verify.sh` are GNOME-baseline workflows, **not** Fedora 45 KDE Graphite restore commands. Do not run them on the current host for this project.

This first change is **documentation and read-only inventory only**. It does not install packages, enable repositories, change the display manager, write desktop settings, or switch launchers.

## Target components (pins pending)

- **OS, drivers, and session:** Fedora 45 repositories/packages, Plasma Wayland, KWin, Qt/KF6, NVIDIA, portals, session/login path, monitor/suspend behavior.
- **Graphite appearance:** neutral charcoal palette based on Finder's dark “Information about…” dialog; no purple accents. Main Finder sidebar remains a visual review item in the 2026-11-12 screenshot. The v0.4 QSS is **a candidate**, not an accepted release.
- **Finder KDE LAB:** exact upstream/fork commit and patch set, reproducible build dependencies, isolated binary, staged QSS, launchers, file/KIO actions, network navigation, search, progress indicator, column view, properties dialogs, localization.
- **Krema Dock / AppBay:** package/source versions, pinned launchers and runtime behavior. AppBay applet ID 100 is *host-specific* and must be dynamically discovered, never hard-coded.
- **KDE tweaks:** Kvantum, Tahoe-derived themes/icons, panel layout, KWin rules, Flex Hub patches, global menu, shortcuts, user-level localization, Bluetooth/audio/brightness/monitor controls.
- **Shared application and system behavior:** XDG portals, MIME associations, file dialogs, KWallet/keyring boundaries, networking/Tailscale, accessibility, USB storage, resume, external display.

See `kde/graphite/component-matrix.tsv` for explicit status. **No item is promoted to PINNED/ACCEPTED by this plan.**

## Recovery architecture

1. **Independent base:** install an official, known Fedora 45 image in a disposable VM; record base package provenance and target architecture.
2. **Read-only inventory:** document package names/versions, component versions, managed configuration filenames, artifact hashes, and observed dependencies. The inventory helper reports only presence and coarse environment information; it does not archive or publish private configuration.
3. **Review and pin:** add individually reviewed, license-compatible artifacts to manifests with exact versions/commits/digests. Keep locally built or custom components pinned to sources and reproducible build instructions.
4. **Restore profile:** implement a *separate, opt-in*, fail-closed KDE installer that is inert without a matching Fedora/Plasma profile and explicit approval. Never call the GNOME `install.sh` as a shortcut.
5. **Isolated verification:** clean-room VM install, static checks, runtime acceptance, GUI screenshots/interaction, negative/rollback cases, a repeat clean-room run, and machine-specific physical follow-up.
6. **Promotion:** update `PROJECT-STATUS.md`, `ROADMAP.md`, and restore documentation only after the full Fedora 45 KDE criteria are demonstrably met.

## Acceptance gates

| Gate | Requirement | Current status |
| --- | --- | --- |
| G0 | Existing Fedora 44/GNOME restore remains unchanged | DESIGN SAFEGUARD |
| G1 | Complete private-safe Fedora 45/KDE component inventory and pins | HOLD |
| G2 | Opt-in KDE installer with dry-run/preflight, exact-state verifier, rollback | HOLD |
| G3 | Disposable Fedora 45 VM clean-room restore and repeatable artifact checks | HOLD |
| G4 | Finder Graphite GUI tests: sidebar, properties, tabs, search, network/KIO, column view | HOLD |
| G5 | XDG portals, MIME, KWallet, Bluetooth, audio, external display, NVIDIA suspend/resume | HOLD |
| G6 | Signed-off security checks, backup/restore acceptance, private data boundary | HOLD |
| G7 | Full KDE desired-state promotion; only then consider custom install media | HOLD |

## Privacy and safety boundary

Do not commit raw `~/.config` trees, `plasma-org.kde.plasma.desktop-appletsrc`, UUIDs, hostnames, disks, tokens, VPN state, Wi-Fi credentials, browser profiles, backup payloads, source URLs containing secrets, or screenshots that disclose private file names. Review and normalize each configuration item before publication. Keep machine-specific mappings and private backups outside public Git.

No direct modifications to production system files are authorized by this document. A future recovery procedure must offer a dry run, explicit target checks, backups, rollback, and a separate disposable test first.

## Next execution

1. Run `bash scripts/inventory-kde-graphite-readonly.sh --read-only` **locally** and inspect output before sharing it.
2. Produce a private, redacted config inventory and versions/hashes of the actual active Finder/Krema/AppBay/theme artifacts.
3. Fill the component matrix with reviewed evidence and prepare a first clean-room VM setup proposal.
4. Keep tracking under Issue #12; do **not** create a second architecture issue solely for Graphite.

**Not part of this milestone:** remix ISO generation, modifying `install.sh`, automatic package installation, writing to KDE configuration, or declaring Fedora 45/KDE restore PASS.
