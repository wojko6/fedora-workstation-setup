# Documentation index

This directory contains the reviewed operational and validation documentation for the Fedora workstation desired state.

## Restore and recovery

- [RESTORE.md](RESTORE.md) — normal rebuild procedure from a clean Fedora installation.
- [CLEAN-ROOM-RESTORE-REPORT.md](CLEAN-ROOM-RESTORE-REPORT.md) — clean-room restore validation and lessons learned.
- [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) — offline disaster-recovery strategy and validated recovery generations.
- [DISASTER-RECOVERY-RUNBOOK.md](DISASTER-RECOVERY-RUNBOOK.md) — detailed total-failure recovery runbook from Live USB through final verification.
- [UPGRADE.md](UPGRADE.md) — controlled Fedora major-upgrade lifecycle and dated 2026-11-10 physical-host migration, with clean-room/reproducible-baseline gate still open.
- [upgrade-preflights/2026-11-04-fedora45-nvidia620.md](upgrade-preflights/2026-11-04-fedora45-nvidia620.md) — historical 2026-11-04 B1–B8 Fedora 45/KDE/NVIDIA 620 preflight; B9 and HOLD describe that date, superseded as physical-host state by the actual 2026-11-10 upgrade (clean-room promotion still pending).

## Desktop environments and localization

- [kde-appbay-krema-launchpad-2026-11-11.md](kde-appbay-krema-launchpad-2026-11-11.md) — native Plasma AppBay + Krema dock activation, model-refresh fix, known failed standalone-window workarounds and operator-verified UI acceptance (Fedora 45, 2026-11-11; restore promotion remains HOLD).
- [WORKLOG-2026-11-11.md](WORKLOG-2026-11-11.md) — operator-confirmed KDE localization phases 7–9, AppBay native Launchpad + Krema integration, Plasma applet configuration sidebar width change, post-install hash evidence and remaining validation gates (2026-11-11; not a clean-room acceptance).

- [kde-localization-audit-2026-11-10.md](kde-localization-audit-2026-11-10.md) — Fedora 45 KDE Flex Hub / Panel Colorizer localization audit and staged/apply evidence, partial visual acceptance, unresolved English weather metrics, KDE session incident and phase-7 HOLD.
- [../localization/kde-tahoe/README.md](../localization/kde-tahoe/README.md) — KDE Mac Tahoe Liquid B291/B292 Polish Global Menu + Launcher catalogs, hashes, user-only restore, and visual verification (2026-11-07; does not promote KDE baseline).

- [LOCALIZATION-STATUS.md](LOCALIZATION-STATUS.md) — repository-managed Polish localization coverage, version pins, and verification strategy.
- [../localization/STYLE-GUIDE.md](../localization/STYLE-GUIDE.md) — Polish UI terminology, gettext metadata, and context-sensitive consistency rules.
- [gnome-extension-audit-2026-09-17.md](gnome-extension-audit-2026-09-17.md) — accepted GNOME extension compatibility refresh for Fedora 44 / GNOME 50.4.
- [../gnome/README.md](../gnome/README.md) — GNOME desired-state policy, extension inventory, and Dhruva handling.
- [Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12) — planned GNOME + KDE Plasma coexistence design; GNOME remains the accepted baseline until KDE passes validation.

## Experimental software and integrations

- [opennow-pl-1.0.5-2026-11-12.md](opennow-pl-1.0.5-2026-11-12.md) — OpenNOW PL 1.0.5 audit, nine catalog edits, FPS Auto QML correction, patchelf 0.19.1 and final Wayland/Krema acceptance (2026-11-12).
- [WORKLOG-2026-11-12.md](WORKLOG-2026-11-12.md) — dated OpenNOW final build v4.1, operator-confirmed application activation and remaining language/streaming gates.


- [TEST-WATCHLIST.md](TEST-WATCHLIST.md) — central cross-project candidate list (NectarLink, local AI/MCP, monitoring, KDE tools and model experiments), priorities, safety gates and existing issue links; **not** an approved deployment plan.

## Portfolio case studies

- [case-studies/README.md](case-studies/README.md) — recruiter-friendly case studies covering reproducible workstation engineering, Tailscale/firewalld isolation, and GNOME localization/integrity debugging.

## Project status

- [../ROADMAP.md](../ROADMAP.md) — canonical technical roadmap, sequencing and promotion gates.
- [../PROJECT-STATUS.md](../PROJECT-STATUS.md) — current physical Fedora 45/KDE state, distinct from the last fully accepted historical Fedora 44/GNOME restore baseline.
- [WORKLOG-2026-09-22.md](WORKLOG-2026-09-22.md) — day-close worklog recording the physical visual validation of Polish Plymouth offline updates.
- [WORKLOG-2026-09-24.md](WORKLOG-2026-09-24.md) — roadmap setup, Tailscale firewalld isolation, GSConnect/ddterm v73 maintenance, complete Ptyxis 50.1 localization closure, and final physical acceptance.
- [WORKLOG-2026-09-25.md](WORKLOG-2026-09-25.md) — ArcMenu v74, DING v97 menu completion, GSConnect v73 consistency validation, Helium 0.18.1.1 re-audit, and final zero-warning physical acceptance.
- [WORKLOG-2026-09-26.md](WORKLOG-2026-09-26.md) — User Themes v79 localization, selective Polish extension display names, GNOME metadata-cache diagnosis, tree-lock promotion, desired-state reconciliation, and PASS=258 physical acceptance.
- [WORKLOG-2026-10-01.md](WORKLOG-2026-10-01.md) — syslog-ng/Tailscale boot-race remediation plus the DING v99 managed-system lifecycle migration and final PASS=266 physical acceptance.
- [WORKLOG-2026-10-10.md](WORKLOG-2026-10-10.md) — Fedora 44 KDE Plasma 6.7.5 pilot, failed GNOME fallback, KDE/Xwayland recovery, DrKonqi timeout closure, ASUS service audit, deferred Brave issue, and AK820 USB diagnostics; promotion remains pending.
- [WORKLOG-2026-10-11.md](WORKLOG-2026-10-11.md) — signed NVIDIA 610.57.04 rollback with an offline 615 recovery set, DNF/GDM recovery incident, two successful deep GPU resumes, reproducible PlasmaQuick screen-lock SIGSEGV (2/2), and upstream KDE Bug #526934; KDE desired-state promotion remains pending.
- [WORKLOG-2026-10-13.md](WORKLOG-2026-10-13.md) — DNF re-upgrade to NVIDIA 615, repeat black-screen diagnosis, verified 610 rollback, ten DNF version locks, selected recovery kernel, and one successful deep resume.
- [WORKLOG-2026-11-10.md](WORKLOG-2026-11-10.md) — physical Fedora 45 migration, recovery checkpoints, NVIDIA 620 deep resume warning, ASUS/Pi-hole ingestion, VirtualBox UEFI start, IMSettings cleanup and KDE Polish localization phases 4–7; full reproducible-baseline promotion remains HOLD.
- [WORKLOG-2026-11-07.md](WORKLOG-2026-11-07.md) — KDE Tahoe B291/B292 Polish UI verification and archive, Fedora 44/DNF5/Flatpak no-change inventory, nine-upgrade dry run, and the explicit 2026-11-08 update deferral.
- [incidents/2026-10-13-nvidia-615-resume-regression.md](incidents/2026-10-13-nvidia-615-resume-regression.md) — detailed incident evidence, rollback procedure, bounded validation and unresolved KDE screen-lock risks.

## Verification entrypoints

- `bash scripts/check-static.sh` — repository-only validation.
- `bash scripts/verify.sh` — live physical-host verification after restore and GNOME session restart.
- `bash scripts/audit-extension-runtime.sh` — extension-focused runtime audit.

The public repository intentionally excludes credentials, machine secrets, private backup artifacts, and other sensitive user data.
