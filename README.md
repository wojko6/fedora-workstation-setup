# Fedora Workstation Setup

Reproducible setup for my Fedora workstation.

The goal of this repository is to rebuild the workstation after a clean Fedora installation without restoring an old system image. It documents and automates packages, GNOME configuration, extensions, desktop launchers, networking fixes, selected security hardening, and repository-managed localization.

## Current baseline

- Fedora 44
- GNOME 50.5
- Wayland
- Lenovo Legion 5 15ACH6H
- Wi-Fi: Realtek RTL8852AE (`rtw89_8852ae`)

## Validation status

The historical Fedora 44 / GNOME 50.4 baseline was validated with a clean-room restore in an Oracle VirtualBox VM. The current physical workstation has since advanced to GNOME Shell 50.5.

Clean-room result:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

After the 2026-09-21 localization closure and a fresh verification from the canonical checkout, the physical workstation completed the current accepted run with:

```text
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current complete accepted physical-host aggregate for Fedora 44 / GNOME 50.5. It includes the repository-managed 2026-09-21 localization additions for Blur my Shell, Clipboard Indicator, Extension Manager, Helium, and GNOME Tweaks. A private GNOME Weather custom location remains part of the validated physical desired state, while its identifying name and coordinates are intentionally excluded from the public repository.

Repository changes are guarded by a static validation workflow. The same `scripts/check-static.sh` entrypoint is used locally and in GitHub Actions to validate Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON files, and desired-state inventory consistency.

The 2026-09-17 extension compatibility refresh accepted ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes into the continuing desired state. Freon also passed compatibility testing at that time but was later deliberately removed. Media Controls was removed because the installed release did not declare GNOME 50 compatibility, while Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks. Advanced Media Controller v31 / 6.5 was subsequently added after physical-host testing. See [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md).

GSConnect was validated beyond shell-extension state: its user D-Bus service was registered and responsive, and the `kdeconnect` firewalld service was confirmed in the dedicated active Wi-Fi `workstation-kdeconnect` zone. Phone-side Tailscale split-tunneling policy is intentionally outside Fedora desired state.

The physical validation also includes reproducible LLMNR disablement, kernel pointer hardening, disabled GNOME/GVfs WS-Discovery, persistent Wi-Fi assignment to the dedicated firewalld `workstation-kdeconnect` zone, successful operation after the NVIDIA 615.71.09 update, an active Secure Boot path with a signed NVIDIA kernel module, and reproducible DDC/CI support for external-monitor brightness control. LUKS remains explicitly deferred; the repository does not claim full-disk encryption for the current installation.

NordVPN, gNordVPN-Local, and Freon are intentionally absent from the current workstation desired state. Tailscale remains the supported overlay/VPN component tracked by the repository.

## Polish localization

The desired state includes reproducible Polish localization support for selected GNOME Shell extensions. The Dhruva integration maintains a 393-message gettext catalog, a 20-patch source localization set, and generated Polish CLDR metadata for all 1907 emoji used by the tested extension source. GSConnect v72 and Tiling Shell v76 / 17.3 have minimal repository-managed completion overlays for demonstrated upstream gaps.

The repository also manages localization for Just Perfection v37, Spotlight v15 / 2026.15, Space Bar v39, Vitals v85, ddterm v72, Advanced Media Controller v31 / 6.5, Papers 49.8 / Nautilus document properties, Plymouth offline updates, and Ptyxis 50.1. Space Bar uses an exact-version controlled source localization because its audited release has no usable gettext path. Advanced Media Controller uses a complete 276-entry Polish gettext catalog pinned to the exact v31 / 6.5 build and verified with a runtime gettext smoke test. Vitals and ddterm use minimal completion strategies over demonstrated upstream gaps. Papers uses a minimal merged gettext overlay, Plymouth persists Fedora's existing Polish catalog and locale data into initramfs, and Ptyxis uses a minimal main-domain bridge so libadwaita's existing Polish About-dialog strings are activated.

`scripts/install-localizations.sh` now invokes 15 version-specific GNOME-extension localization installers plus six application/system stages: Papers, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks. Their dedicated checks are integrated into the main `scripts/verify.sh`. The 2026-09-21 audit-driven additions for Blur my Shell v72, Clipboard Indicator v71, Extension Manager 0.6.5, Helium 0.17.2.1, and GNOME Tweaks 49.0 are repository-managed and included in the clean `PASS=236 WARN=0 FAIL=0 SKIP=0` physical verification. The GNOME Tweaks `Hinting` terminology override is physically confirmed as `Dopasowanie do pikseli`. VSCodium 1.135.06055 remains intentionally deferred and is not claimed as reproducibly localized. Details are tracked in [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md).

Dhruva's dock state is also reproducible. The repository stores a sanitized desired dock order and application-folder definition in `gnome/dhruva/dock-state.json`; `scripts/install-dhruva-config.sh` restores that state after the GNOME configuration stage, and `scripts/verify.sh` detects drift. Machine-specific paths and private local folder state are intentionally excluded.


GNOME Weather custom locations are reproducible without publishing private location data or storing opaque dconf state. The public repository contains only `gnome/weather-locations.example.tsv`; real names and WGS84 coordinates belong in the gitignored `gnome/weather-locations.local.tsv`. `scripts/manage-weather-locations.py` uses libgweather serialization to install and verify exactly one matching private location, and the restore stage runs after the curated GNOME dconf restore so it is not overwritten.

The latest private offline disaster-recovery generation, created on 2026-09-21 after the clean physical verification, passed Zstandard integrity tests and a full 21-entry SHA-256 manifest verification. The private artifacts remain outside Git.

See [`PROJECT-STATUS.md`](PROJECT-STATUS.md) for the current acceptance and security-validation status, [`docs/README.md`](docs/README.md) for the documentation index, [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md) for the clean-room validation report, [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md) for the GNOME extension refresh, [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md) for Polish localization coverage, and [`docs/DISASTER-RECOVERY.md`](docs/DISASTER-RECOVERY.md) for the offline disaster-recovery strategy. The detailed total-failure operational sequence is documented separately in [`docs/DISASTER-RECOVERY-RUNBOOK.md`](docs/DISASTER-RECOVERY-RUNBOOK.md).

## Third-party components and project scope

GNOME Shell extensions integrated by this repository remain the work of their respective upstream authors and retain their upstream licenses. This project does not claim authorship of those extensions. Its scope is reproducible deployment, version/inventory tracking, configuration, compatibility and runtime validation, selected localization work, conflict handling, security integration, and documentation.

## Design

The repository stores the desired configuration, not private user data. Secrets, Wi-Fi credentials, SSH private keys, browser profiles, password-manager vaults, raw shell history, VPN authentication state, private/precise location data, and other sensitive state must never be committed.

## Restore flow

```bash
git clone https://github.com/wojko6/fedora-workstation-setup.git
cd fedora-workstation-setup

# Review the trusted physical Wi-Fi profile first; do not derive trust
# automatically from whichever network happens to be active.
nmcli -f NAME,UUID,TYPE connection show

TRUSTED_WIFI_UUID='<reviewed-networkmanager-uuid>' bash install.sh
```

On a physical host, `TRUSTED_WIFI_UUID` is mandatory and is deliberately kept outside Git. The firewalld stage rejects an active Wi-Fi connection whose UUID does not match the reviewed value before changing NetworkManager or firewalld state. `TRUSTED_WIFI_PROFILE` may additionally be supplied to pin the expected human-readable profile name. In a virtualized clean-room environment without a trusted physical Wi-Fi profile, the trusted-Wi-Fi firewall stage is an explicit environment `SKIP`.

The dedicated `workstation-kdeconnect` zone is managed as exact state for the trusted Wi-Fi profile: only `dhcpv6-client`, `mdns`, and `kdeconnect` services are allowed; SSH, forwarding, masquerade, explicit ports/protocols/sources, forward/source ports, ICMP blocks, and rich rules are removed. The stage snapshots its previous zone/profile state and rolls back on configuration failure.

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

## Verification

After restore and the required GNOME session restart:

```bash
bash scripts/verify.sh
```

Current accepted physical-workstation result:

```text
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

Repository-only validation can be run with:

```bash
bash scripts/check-static.sh
python3 scripts/validate-repository.py
```

The historical clean-room result and environment-specific SKIP interpretation are documented in [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md).

## Limitations

This repository is a reproducible rebuild definition, not a full-disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, Tailscale node identity, and private signing material remain outside Git.

## Maintenance

After material Fedora, GNOME, kernel/NVIDIA, extension, localization, restore, or security-policy changes:

1. run repository static validation;
2. run the full physical-host verifier;
3. repeat clean-room restore testing when the restore path or supported baseline changes;
4. update the documented accepted baseline only after those checks pass.
