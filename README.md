# Fedora Workstation Setup

Reproducible setup for my Fedora workstation.

The goal of this repository is to rebuild the workstation after a clean Fedora installation without restoring an old system image. It documents and automates packages, GNOME configuration, extensions, desktop launchers, networking fixes, and selected security hardening.

## Current baseline

- Fedora 44
- GNOME 50.4
- Wayland
- Lenovo Legion 5 15ACH6H
- Wi-Fi: Realtek RTL8852AE (`rtw89_8852ae`)

## Validation status

The Fedora 44 / GNOME 50.4 baseline has been validated with a clean-room restore in an Oracle VirtualBox VM.

Clean-room result:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

The current physical workstation desired state was subsequently validated after security hardening and a controlled NVIDIA/graphics-stack update:

```text
PASS=168 WARN=0 FAIL=0 SKIP=0
```

All required GNOME extensions reported `ACTIVE`, and the curated GNOME desired-state audit matched 78 checks. Environment-specific VM exclusions are reported explicitly as `SKIP` rather than hidden or treated as restore warnings.

The physical validation includes reproducible LLMNR disablement, kernel pointer hardening, disabled GNOME/GVfs WS-Discovery, persistent Wi-Fi assignment to firewalld's `public` zone, and successful operation after the NVIDIA 615.71.09 update. Secure Boot and LUKS remain explicitly deferred items; the repository does not claim either as currently enabled.

See [`PROJECT-STATUS.md`](PROJECT-STATUS.md) for the current acceptance and security-validation status, [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md) for the clean-room validation report, and [`docs/DISASTER-RECOVERY.md`](docs/DISASTER-RECOVERY.md) for the offline disaster-recovery strategy and the 2026-09-15 backup-integrity validation.

## Design

The repository stores the desired configuration, not private user data. Secrets, Wi-Fi credentials, SSH private keys, browser profiles, password-manager vaults, raw shell history, VPN authentication state, and other sensitive state must never be committed.

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
- `security/` — selected reproducible workstation hardening
- `desktop/` — user launchers and desktop configuration
- `patches/` — local changes that cannot be expressed as normal settings
- `scripts/` — installation and verification stages
- `docs/` — restore, validation, recovery, and maintenance documentation

## Verification

After restore and the required GNOME session restart:

```bash
bash scripts/verify.sh
```

`FAIL` indicates a required state that is not satisfied. `WARN` indicates an actionable mismatch that needs review. `SKIP` is reserved for checks that are intentionally not applicable to the detected environment, such as physical Wi-Fi or host-only driver checks inside the clean-room VM.

## Status

**Validated for the Fedora 44 / GNOME 50.4 baseline.** The latest physical-workstation verification completed with `PASS=168 WARN=0 FAIL=0 SKIP=0`. Future Fedora or GNOME upgrades should be followed by another clean-room validation before declaring the new baseline accepted.
