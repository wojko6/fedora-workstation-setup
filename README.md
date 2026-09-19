# Fedora Workstation Setup

Reproducible setup for my Fedora workstation.

The goal of this repository is to rebuild the workstation after a clean Fedora installation without restoring an old system image. It documents and automates packages, GNOME configuration, extensions, desktop launchers, networking fixes, selected security hardening, and repository-managed localization.

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

After Freon was intentionally removed, Advanced Media Controller v31 / 6.5 was added to desired state, and the final Vitals, ddterm, and Advanced Media Controller localization checks were integrated into the main verifier, the physical workstation completed the final acceptance run with:

```text
PASS=226 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current accepted physical-host aggregate for Fedora 44 / GNOME 50.4. The localization restore and verification flow is fully integrated and the current desired state has zero warnings and zero failures.

Repository changes are guarded by a static validation workflow. The same `scripts/check-static.sh` entrypoint is used locally and in GitHub Actions to validate Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON files, and desired-state inventory consistency.

The 2026-09-17 extension compatibility refresh accepted ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes into the continuing desired state. Freon also passed compatibility testing at that time but was later deliberately removed. Media Controls was removed because the installed release did not declare GNOME 50 compatibility, while Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks. Advanced Media Controller v31 / 6.5 was subsequently added after physical-host testing. See [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md).

GSConnect was validated beyond shell-extension state: its user D-Bus service was registered and responsive, and the `kdeconnect` firewalld service was confirmed in the dedicated active Wi-Fi `workstation-kdeconnect` zone. Phone-side Tailscale split-tunneling policy is intentionally outside Fedora desired state.

The physical validation also includes reproducible LLMNR disablement, kernel pointer hardening, disabled GNOME/GVfs WS-Discovery, persistent Wi-Fi assignment to the dedicated firewalld `workstation-kdeconnect` zone, successful operation after the NVIDIA 615.71.09 update, an active Secure Boot path with a signed NVIDIA kernel module, and reproducible DDC/CI support for external-monitor brightness control. LUKS remains explicitly deferred; the repository does not claim full-disk encryption for the current installation.

NordVPN, gNordVPN-Local, and Freon are intentionally absent from the current workstation desired state. Tailscale remains the supported overlay/VPN component tracked by the repository.

## Polish localization

The desired state includes reproducible Polish localization support for selected GNOME Shell extensions. The Dhruva integration maintains a 393-message gettext catalog, a 20-patch source localization set, and generated Polish CLDR metadata for all 1907 emoji used by the tested extension source. GSConnect v72 and Tiling Shell v76 / 17.3 have minimal repository-managed completion overlays for demonstrated upstream gaps.

The repository also manages localization for Just Perfection v37, Spotlight v15 / 2026.15, Space Bar v39, Vitals v85, ddterm v72, and Advanced Media Controller v31 / 6.5. Space Bar uses an exact-version controlled source localization because its audited release has no usable gettext path. Advanced Media Controller uses a complete 276-entry Polish gettext catalog pinned to the exact v31 / 6.5 build and verified with a runtime gettext smoke test. Vitals and ddterm use minimal completion strategies over demonstrated upstream gaps.

All 11 version-specific localization installers are invoked by `scripts/install-localizations.sh`, and their dedicated checks are integrated into the main `scripts/verify.sh`. The complete localization set has passed the final physical-host verifier with zero warnings and zero failures. Full details are tracked in [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md).

Dhruva's dock state is also reproducible. The repository stores a sanitized desired dock order and application-folder definition in `gnome/dhruva/dock-state.json`; `scripts/install-dhruva-config.sh` restores that state after the GNOME configuration stage, and `scripts/verify.sh` detects drift. Machine-specific paths and private local folder state are intentionally excluded.

See [`PROJECT-STATUS.md`](PROJECT-STATUS.md) for the current acceptance and security-validation status, [`docs/README.md`](docs/README.md) for the documentation index, [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md) for the clean-room validation report, [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md) for the GNOME extension refresh, [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md) for Polish localization coverage, and [`docs/DISASTER-RECOVERY.md`](docs/DISASTER-RECOVERY.md) for the offline disaster-recovery strategy.

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

`install.sh` orchestrates the restore stages in `scripts/` and is designed to remain conservative and safe to rerun where practical. It deliberately does **not** run the final verifier in the same GNOME session, because newly installed extensions and Shell metadata may not be fully active until the session is restarted. After `install.sh` completes, sign out and back in (or reboot), then run `bash scripts/verify.sh` from the repository directory.

## Repository layout

- `packages/` — RPM and Flatpak package manifests
- `gnome/` — GNOME and extension configuration
- [`localization/`](localization/README.md) — repository-managed translation sources
- `network/` — reproducible network fixes
- `security/` — selected reproducible workstation hardening
- `desktop/` — user launchers and desktop configuration
- [`patches/`](patches/README.md) — local changes that cannot be expressed as normal settings
- [`scripts/`](scripts/README.md) — installation, audit, and verification stages
- [`docs/`](docs/README.md) — restore, validation, recovery, and maintenance documentation

```markdown
## Verification

After restore and the required GNOME session restart:

```bash
scripts/verify.sh
The final physical workstation verification completed with:

PASS=226
WARN=0
FAIL=0
SKIP=0

## Overview

This repository defines a declarative workstation rebuild process.

The goal is to recreate a validated Fedora workstation after a clean installation without restoring an opaque system image.

The pipeline manages:

- package installation,
- external repositories,
- Flatpak applications,
- GNOME configuration,
- GNOME extensions,
- Polish localization fixes,
- desktop launchers,
- network configuration,
- firewall configuration,
- security hardening,
- automated verification.

## Current baseline

- Fedora 44
- GNOME Shell 50.4
- Wayland session
- Tested on Lenovo Legion 5 15ACH6H
- Wi-Fi adapter: Realtek RTL8852AE

## Validation status

The current workstation baseline has been validated using:

- Oracle VirtualBox clean-room restore testing
- Physical workstation verification

GNOME extension management

GNOME extensions are managed as controlled components.

The repository tracks:

extension inventory,
version compatibility,
installation state,
runtime validation,
configuration restore.

Validated components include:

ArcMenu
Dhruva
GSConnect
Tiling Shell
Just Perfection
Spotlight
Space Bar
Vitals
ddterm
Advanced Media Controller

Extension versions are pinned where required to maintain reproducibility.

Localization engineering

The repository provides version-specific Polish localization fixes where upstream support is incomplete or unavailable.

Implemented solutions include:

gettext catalog corrections,
gettext domain fixes,
metadata localization,
deterministic .mo generation,
automated verification.

Validated localization targets include:

ArcMenu
Dhruva
GSConnect
Tiling Shell
Just Perfection
Spotlight
Space Bar
Vitals
ddterm
Advanced Media Controller

All localization installers are integrated into:
scripts/install-localizations.sh

Verification is performed by:
scripts/verify.sh

Security hardening

Implemented security controls include:

LLMNR disabled,
WSD discovery disabled,
kernel hardening settings,
dedicated KDE Connect firewall zone,
Secure Boot validation,
NVIDIA signed module verification.

The project keeps security changes reproducible and validated.

Network configuration

Network changes are applied through controlled scripts.

Implemented:

deterministic Wi-Fi power-save configuration,
firewall zone assignment,
KDE Connect isolation.

VPN / overlay networking:

Tailscale is the supported overlay component tracked by this repository.

NordVPN, gNordVPN-Local, and Freon are outside the current desired workstation state.

Recovery and validation model

The repository does not rely on manual confirmation only.

Every important configuration change follows the workflow:

Configuration change
        |
        v
Automated verification
        |
        v
Accepted desired state

Validation checks include:

installed packages,
repositories,
GNOME extensions,
localization state,
GNOME configuration,
firewall configuration,
security settings,
recovery readiness.
Engineering principles

Key principles:

configuration should be reproducible,
every change should have validation,
dependencies should be pinned where possible,
documentation is part of infrastructure quality.
Project status

Version:
v1.0-fedora44-gnome50-stable

Current state:

Validated Fedora Workstation baseline.

The repository is ready for reproducible rebuild testing and further controlled improvements.

Limitations

This repository is not a full disk backup.

The following remain outside Git:

personal files,
credentials,
SSH private keys,
Wi-Fi secrets,
browser profiles,
password manager data,
Tailscale node identity,
private signing material.
Future work

Planned maintenance:

keep package and extension pins current,
repeat clean-room restore tests after major Fedora/GNOME changes,
maintain localization verification after extension updates,
evaluate full-disk encryption during a future controlled reinstall.
