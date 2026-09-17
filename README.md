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

After Freon was intentionally removed from desired state, the last completed full physical-workstation verification before the final localization integration reported:

```text
PASS=214 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

Since that run, Advanced Media Controller v31 / 6.5 was added to desired state and the final AppIndicator, Vitals, ddterm, and Advanced Media Controller localization checks were integrated into the main verifier. A new full physical-host verification is therefore required before recording the next aggregate PASS count. The acceptance criterion remains zero warnings and zero failures for the current desired state.

Repository changes are guarded by a static validation workflow. The same `scripts/check-static.sh` entrypoint is used locally and in GitHub Actions to validate Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON files, and desired-state inventory consistency.

The 2026-09-17 extension compatibility refresh accepted ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes into the continuing desired state. Freon also passed compatibility testing at that time but was later deliberately removed. Media Controls was removed because the installed release did not declare GNOME 50 compatibility, while Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks. Advanced Media Controller v31 / 6.5 was subsequently added after physical-host testing. See [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md).

GSConnect was validated beyond shell-extension state: its user D-Bus service was registered and responsive, and the `kdeconnect` firewalld service was confirmed in the active Wi-Fi `public` zone. Phone-side Tailscale split-tunneling policy is intentionally outside Fedora desired state.

The physical validation also includes reproducible LLMNR disablement, kernel pointer hardening, disabled GNOME/GVfs WS-Discovery, persistent Wi-Fi assignment to firewalld's `public` zone, successful operation after the NVIDIA 615.71.09 update, an active Secure Boot path with a signed NVIDIA kernel module, and reproducible DDC/CI support for external-monitor brightness control. LUKS remains explicitly deferred; the repository does not claim full-disk encryption for the current installation.

NordVPN, gNordVPN-Local, and Freon are intentionally absent from the current workstation desired state. Tailscale remains the supported overlay/VPN component tracked by the repository.

## Polish localization

The desired state includes reproducible Polish localization support for selected GNOME Shell extensions. The Dhruva integration maintains a 393-message gettext catalog, a 20-patch source localization set, and generated Polish CLDR metadata for all 1907 emoji used by the tested extension source. GSConnect v72 and Tiling Shell v76 / 17.3 have minimal repository-managed completion overlays for demonstrated upstream gaps.

The repository also manages localization for Just Perfection v37, Spotlight v14 / 2026.11, Space Bar v39, AppIndicator v64, Vitals v85, ddterm v72, and Advanced Media Controller v31 / 6.5. Space Bar uses an exact-version controlled source localization because its audited release has no usable gettext path. Advanced Media Controller uses a complete 276-entry Polish gettext catalog pinned to the exact v31 / 6.5 build and verified with a runtime gettext smoke test. Vitals, AppIndicator, and ddterm use minimal completion strategies over demonstrated upstream gaps.

All version-specific localization installers are invoked by `scripts/install-localizations.sh`, and their dedicated checks are integrated into the main `scripts/verify.sh`. Full details are tracked in [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md).

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

`install.sh` orchestrates the restore stages in `scripts/` and is designed to remain conservative and safe to rerun where practical. It deliberately does **not** run the final verifier in the same GNOME session, because newly installed extensions and Shell metadata may not be fully active until the session is restarted. After `install.sh` completes, sign out and back in (or reboot), then run `bash scripts/verify.sh` from the repository directory.

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

For repository-only static validation that does not require the live Fedora desktop state:

```bash
bash scripts/check-static.sh
```

For extension-focused validation:

```bash
bash scripts/audit-extension-runtime.sh
```

## Status

**Fedora 44 / GNOME 50.4 remains the accepted platform baseline.** The last full physical-host verification before the final localization wiring completed with `PASS=214 WARN=0 FAIL=0 SKIP=0` and `VERIFY_RC=0`. The repository now also tracks Advanced Media Controller v31 / 6.5 and the completed AppIndicator, Vitals, ddterm, and Advanced Media Controller Polish localization checks. Run the main verifier once more on the physical workstation before recording the next accepted aggregate. Future Fedora or GNOME upgrades should be followed by another clean-room and physical-host validation before declaring the new baseline accepted.
