# Documentation index

This directory contains the reviewed operational and validation documentation for the Fedora workstation desired state.

## Restore and recovery

- [RESTORE.md](RESTORE.md) — normal rebuild procedure from a clean Fedora installation.
- [CLEAN-ROOM-RESTORE-REPORT.md](CLEAN-ROOM-RESTORE-REPORT.md) — clean-room restore validation and lessons learned.
- [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) — offline disaster-recovery strategy and validated recovery generations.
- [DISASTER-RECOVERY-RUNBOOK.md](DISASTER-RECOVERY-RUNBOOK.md) — detailed total-failure recovery runbook from Live USB through final verification.
- [UPGRADE.md](UPGRADE.md) — controlled Fedora major-release upgrade lifecycle with VM qualification and physical acceptance gates.

## GNOME and localization

- [LOCALIZATION-STATUS.md](LOCALIZATION-STATUS.md) — repository-managed Polish localization coverage, version pins, and verification strategy.
- [gnome-extension-audit-2026-09-17.md](gnome-extension-audit-2026-09-17.md) — accepted GNOME extension compatibility refresh for Fedora 44 / GNOME 50.4.
- [../gnome/README.md](../gnome/README.md) — GNOME desired-state policy, extension inventory, and Dhruva handling.

## Project status

- [../PROJECT-STATUS.md](../PROJECT-STATUS.md) — current accepted physical-host baseline and remaining work.

## Verification entrypoints

- `bash scripts/check-static.sh` — repository-only validation.
- `bash scripts/verify.sh` — live physical-host verification after restore and GNOME session restart.
- `bash scripts/audit-extension-runtime.sh` — extension-focused runtime audit.

The public repository intentionally excludes credentials, machine secrets, private backup artifacts, and other sensitive user data.
