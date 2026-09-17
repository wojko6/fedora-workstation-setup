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

The current physical workstation desired state was subsequently validated after security hardening, a controlled NVIDIA/graphics-stack update, Secure Boot enablement, DDC/CI setup, and the 2026-09-17 GNOME extension compatibility refresh:

```text
PASS=217 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

All required GNOME extensions reported `ACTIVE`, the curated GNOME desired-state audit matched the accepted configuration, and the extension runtime audit completed without unresolved required-state failures. Environment-specific VM exclusions are reported explicitly as `SKIP` rather than hidden or treated as restore warnings.

The 2026-09-17 extension refresh added seven physically validated GNOME 50 extensions to desired state: ArcMenu, Bluetooth Battery Meter, Caffeine, Freon, GSConnect, Tiling Shell, and User Themes. Media Controls was removed because the installed release did not declare GNOME 50 compatibility, while Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks. See [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md).

GSConnect was validated beyond shell-extension state: its user D-Bus service was registered and responsive, and the `kdeconnect` firewalld service was confirmed in the active Wi-Fi zone. Phone-side Tailscale split-tunneling policy is intentionally outside Fedora desired state.

The physical validation also includes reproducible LLMNR disablement, kernel pointer hardening, disabled GNOME/GVfs WS-Discovery, persistent Wi-Fi assignment to firewalld's `public` zone, successful operation after the NVIDIA 615.71.09 update, an active Secure Boot path with a signed NVIDIA kernel module, and reproducible DDC/CI support for external-monitor brightness control. LUKS remains explicitly deferred; the repository does not claim full-disk encryption for the current installation.

The desired state includes reproducible Polish localization support for selected GNOME Shell extensions. The Dhruva integration maintains a 393-message gettext catalog, a 20-patch source localization set, and generated Polish CLDR metadata for all 1907 emoji used by the tested extension source. These artifacts are installed and checked by the repository tooling rather than stored as an opaque modified extension archive. The current localization backlog and upstream Polish-coverage review are tracked in [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md).

Dhruva's dock state is also reproducible. The repository stores a sanitized desired dock order and application-folder definition in `gnome/dhruva/dock-state.json`; `scripts/install-dhruva-config.sh` restores that state after the GNOME configuration stage, and `scripts/verify.sh` detects drift. Machine-specific paths and private local folder state are intentionally excluded.

See [`PROJECT-STATUS.md`](PROJECT-STATUS.md) for the current acceptance and security-validation status, [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md) for the clean-room validation report, [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md) for the GNOME extension refresh, [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md) for Polish localization coverage, and [`docs/DISASTER-RECOVERY.md`](docs/DISASTER-RECOVERY.md) for the offline disaster-recovery strategy.

## Third-party components and project scope

GNOME Shell extensions integrated by this repository remain the work of their respective upstream authors and retain their upstream licenses. This project does not claim authorship of those extensions. Its scope is reproducible deployment, version/inventory tracking, configuration, compatibility and runtime validation, selected localization work, conflict handling, security integration, and documentation.

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
- `localization/` — repository-managed translation sources
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

For extension-focused validation:

```bash
bash scripts/audit-extension-runtime.sh
```

## Status

**Validated for the Fedora 44 / GNOME 50.4 baseline.** The latest physical-workstation verification completed with `PASS=217 WARN=0 FAIL=0 SKIP=0` and `VERIFY_RC=0`. The accepted state includes Secure Boot, signed NVIDIA-module verification, DDC/CI external-monitor brightness support, the validated GNOME extension refresh, GSConnect D-Bus/firewalld integration, and repository-managed Polish GNOME extension localizations including Dhruva. Future Fedora or GNOME upgrades should be followed by another clean-room and physical-host validation before declaring the new baseline accepted.
