# Fedora Workstation Setup

Reproducible setup for my Fedora workstation.

The goal of this repository is to rebuild the workstation after a clean Fedora installation without restoring an old system image. It documents and automates packages, GNOME configuration, extensions, desktop launchers, networking fixes, and selected local patches.

## Current baseline

- Fedora 44
- GNOME 50.4
- Wayland
- Lenovo Legion 5 15ACH6H
- Wi-Fi: Realtek RTL8852AE (`rtw89_8852ae`)

## Validation status

The Fedora 44 / GNOME 50.4 baseline has been validated with a clean-room restore in an Oracle VirtualBox VM.

Final acceptance result:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

All required GNOME extensions reported `ACTIVE`, and the curated GNOME desired-state audit matched 78 checks. Environment-specific VM exclusions are reported explicitly as `SKIP` rather than hidden or treated as restore warnings.

See [`PROJECT-STATUS.md`](PROJECT-STATUS.md) for the current acceptance status, [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md) for the clean-room validation report, and [`docs/DISASTER-RECOVERY.md`](docs/DISASTER-RECOVERY.md) for the offline disaster-recovery strategy and the 2026-09-15 backup-integrity validation.

## Design

The repository stores the desired configuration, not private user data. Secrets, Wi-Fi credentials, SSH private keys, browser profiles, password-manager vaults, raw shell history, and other sensitive state must never be committed.

## Restore flow

```bash
git clone https://github.com/wojko6/fedora-workstation-setup.git
cd fedora-workstation-setup
./install.sh
```

`install.sh` orchestrates the restore stages in `scripts/` and is designed to remain conservative and safe to rerun where practical. GNOME Shell may require a sign-out/sign-in or reboot after newly installed extensions are registered; run `scripts/verify.sh` after the final session restart.

## Repository layout

- `packages/` — RPM and Flatpak package manifests
- `gnome/` — GNOME and extension configuration
- `network/` — reproducible network fixes
- `desktop/` — user launchers and desktop configuration
- `patches/` — local changes that cannot be expressed as normal settings
- `scripts/` — installation and verification stages
- `docs/` — restore and maintenance documentation

## Verification

After restore and the required GNOME session restart:

```bash
bash scripts/verify.sh
```

`FAIL` indicates a required state that is not satisfied. `WARN` indicates an actionable mismatch that needs review. `SKIP` is reserved for checks that are intentionally not applicable to the detected environment, such as physical Wi-Fi or host-only driver checks inside the clean-room VM.

## Status

**Validated for the Fedora 44 / GNOME 50.4 baseline.** Future Fedora or GNOME upgrades should be followed by another clean-room validation before declaring the new baseline accepted.
