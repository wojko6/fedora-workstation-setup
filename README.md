# Fedora Workstation Setup

Reproducible setup for my Fedora workstation.

The goal of this repository is to rebuild the workstation after a clean Fedora installation without restoring an old system image. It documents and automates packages, GNOME configuration, extensions, desktop launchers, networking fixes, selected security hardening, and repository-managed localization.

## Current baseline

- Fedora 44
- GNOME 50.5
- Wayland
- Lenovo Legion 5 15ACH6H
- Wi-Fi: Realtek RTL8852AE (`rtw89_8852ae`)

## Engineering roadmap

The current accepted production baseline remains **Fedora 44 / GNOME Shell 50.5 / Wayland**.

The canonical technical roadmap is maintained in [ROADMAP.md](ROADMAP.md).
It separates near-term hardening, recurring lifecycle maintenance, major
validation milestones and later/conditional work while keeping planned changes
distinct from the accepted desired state.

[Issue #17](https://github.com/wojko6/fedora-workstation-setup/issues/17) remains
the umbrella execution tracker, and the public GitHub Project tracks workflow
state. Individual issues retain their detailed acceptance criteria.

## Validation status

The historical Fedora 44 / GNOME 50.4 baseline was validated with a clean-room restore in an Oracle VirtualBox VM. The current physical workstation has since advanced to GNOME Shell 50.5.

Clean-room result:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

After the 2026-09-25 localization-consistency closure, including ArcMenu v74 runtime binding validation, the completed DING v97 desktop-menu translation pass, and the Helium 0.18.1.1 re-audit, the physical workstation completed the current accepted run with:

```text
PASS=256 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current complete accepted physical-host aggregate for Fedora 44 / GNOME 50.5. It includes the accepted localization state, explicit live security-posture verification, fail-closed required-state enforcement, deterministic whole-tree integrity verification for all 22 enabled user GNOME extensions, ArcMenu v74 / 70.0 with the audited gettext-domain binding fix, GSConnect v73, the fully Polish DING v97 desktop background menu including its Arrange By submenu and `Monitor systemu` action, and Helium 0.18.1.1 / Chromium 154.0.8037.57 with the strict 36-entry DataPack completion. A private GNOME Weather custom location remains part of the validated physical desired state, while its identifying name and coordinates are intentionally excluded from the public repository.

External RPM repository trust is also fail-closed: RPM Fusion, Brave, Helium COPR, and VPCS COPR are checked against reviewed source locations, local trust-anchor material, full OpenPGP fingerprints, package-signature verification, expected package signers, and COPR package scopes. Repository changes are guarded by a static validation workflow. The same `scripts/check-static.sh` entrypoint is used locally and in GitHub Actions to validate Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON files, and desired-state inventory consistency.

The 2026-09-17 extension compatibility refresh accepted ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes into the continuing desired state. Freon also passed compatibility testing at that time but was later deliberately removed. Media Controls was removed because the installed release did not declare GNOME 50 compatibility, while Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks. Advanced Media Controller v31 / 6.5 was subsequently added after physical-host testing. See [`docs/gnome-extension-audit-2026-09-17.md`](docs/gnome-extension-audit-2026-09-17.md).

GSConnect was validated beyond shell-extension state: its user D-Bus service was registered and responsive, and the `kdeconnect` firewalld service was confirmed in the dedicated active Wi-Fi `workstation-kdeconnect` zone. Phone-side Tailscale split-tunneling policy is intentionally outside Fedora desired state.

The workstation also defines a dedicated `workstation-tailscale` firewalld zone for `tailscale0`. Its exact policy is `target=DROP` with no allowed services, ports, protocols, sources, forwarding, masquerade, ICMP inversion, or rich rules. This prevents Tailscale traffic from falling through to Fedora's broader `FedoraWorkstation` default-zone policy while preserving outbound/established Tailscale connectivity. A live 2026-09-24 A/B test changed remote TCP/1716 and TCP/27036 from `open` to `filtered`, the dedicated-zone assignment persisted across reboot, and the final physical verifier accepted both runtime and permanent Tailscale-zone state.

The physical validation also includes reproducible LLMNR disablement, kernel pointer hardening, disabled GNOME/GVfs WS-Discovery, the physically accepted D-H1 trusted-Wi-Fi firewalld boundary, the D-H2/D-H3 fail-closed verifier layer, D-H4 whole-tree GNOME-extension integrity, and a version-pinned DING v97 desktop-menu customization that launches GNOME System Monitor. The active Wi-Fi profile is gated by reviewed NetworkManager UUID and uses the dedicated `workstation-kdeconnect` zone in exact state with only `dhcpv6-client`, `mdns`, and `kdeconnect`; SSH, forwarding, masquerade, explicit ports/protocols/sources and rich rules are absent, while `kdeconnect` is removed from every other permanent zone. The verifier also checks SELinux/AVC state, disabled SSH service/socket and TCP/22 listener state, kernel lockdown, NVIDIA/MOK signing evidence, runtime/permanent firewalld exact state, required RPM/repository/Tailscale/Flatpak state, and all 22 enabled user-extension trees against `gnome/extensions-tree-lock.tsv`; the physical target is accepted only with zero FAIL and zero WARN. The workstation also remained operational after the NVIDIA 615.71.09 update, with an active Secure Boot path and signed NVIDIA kernel module, plus reproducible DDC/CI support for external-monitor brightness control. LUKS remains explicitly deferred; the repository does not claim full-disk encryption for the current installation.

NordVPN, gNordVPN-Local, and Freon are intentionally absent from the current workstation desired state. Tailscale remains the supported overlay/VPN component tracked by the repository.

## Polish localization

The desired state includes reproducible Polish localization support for selected GNOME Shell extensions. The Dhruva integration maintains a 393-message gettext catalog, a 20-patch source localization set, and generated Polish CLDR metadata for all 1907 emoji used by the tested extension source. GSConnect v73 uses a 20-entry managed catalog plus gettext-domain and factory RunCommand-name fixes; Tiling Shell v76 / 17.3 uses a minimal repository-managed completion overlay for demonstrated upstream gaps.

The repository also manages localization for Just Perfection v37, Spotlight v15 / 2026.15, Space Bar v39, Vitals v85, ddterm v73, Advanced Media Controller v31 / 6.5, Papers 49.8 / Nautilus document properties, Plymouth offline updates, and Ptyxis 50.1. Space Bar uses an exact-version controlled source localization because its audited release has no usable gettext path. Advanced Media Controller uses a complete 276-entry Polish gettext catalog pinned to the exact v31 / 6.5 build and verified with a runtime gettext smoke test. Vitals and ddterm use completion strategies over demonstrated upstream gaps; ddterm v73 carries an 18-entry completion plus localized metadata description. Papers uses a minimal merged gettext overlay, Plymouth persists Fedora's existing Polish catalog and locale data into initramfs, and Ptyxis uses a version-pinned main-domain completion covering the audited main window/menu, terminal context menu, search, inspector, title dialog, and search options while also activating libadwaita's Polish About-dialog strings. Those initially audited in-application Ptyxis areas were visually confirmed in Polish on 2026-09-24. A subsequent complete preferences scan found 189 unresolved resource occurrences representing 152 unique msgids across six preference/profile/shortcut resources, and a separate GNOME Shell launcher gap (`New Window`, `New Tab`, `Preferences`) was traced to missing Polish `Name[pl]` entries in the package-owned desktop file. PR #24, squash-merged to `main` as `4141507`, added 162 unique translations from the current audit cycle, exact runtime-resource coverage across eight embedded UI resources, separate gettext checks for the C-generated `Add Link`, `Add Profile`, `Show Fewer Palettes`, and `Select Font` labels, and an exact-build/fingerprint-pinned launcher remediation. The expanded Ptyxis state was installed on the physical Fedora 44 workstation, visually confirmed in Polish, and accepted by the full verifier at `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`. On 2026-09-22, a real physical offline-update cycle visually confirmed the Plymouth screen in Polish, including `Instalowanie aktualizacji…`, `Nie należy wyłączać komputera`, and the translated progress text.

`scripts/install-localizations.sh` manages 27 localization targets/operations: four generic gettext targets, 16 specialized GNOME-extension stages, six application/system stages, and one selective extension display-name stage (Papers, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks). Their dedicated checks are integrated into the main `scripts/verify.sh`. The 2026-09-26 physical acceptance includes User Themes v79 / 50.4, the selective Polish extension display-name pass, ArcMenu v74 / 70.0, GSConnect v73, ddterm v73, complete DING v97 desktop-menu localization, complete Ptyxis 50.1 localization, Blur my Shell v72, the corrected 64-entry Clipboard Indicator v71 completion, Extension Manager 0.6.5, Helium 0.18.1.1 / Chromium 154.0.8037.57, GNOME Tweaks 49.0, and the remaining managed localization targets in the clean `PASS=258 WARN=0 FAIL=0 SKIP=0` full verifier. The GNOME Tweaks `Hinting` terminology override is physically confirmed as `Dopasowanie do pikseli`. VSCodium 1.135.06055 remains intentionally deferred and is not claimed as reproducibly localized. Details are tracked in [`docs/LOCALIZATION-STATUS.md`](docs/LOCALIZATION-STATUS.md).

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

The separate `workstation-tailscale` zone is also managed as exact state. It binds only `tailscale0`, uses a `DROP` target, and exposes no firewalld services or explicit ports. The restore stage can prepare the permanent interface binding even before a private Tailscale node identity is restored; when `tailscale0` exists, runtime assignment is verified as well.

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
PASS=258 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

The 2026-09-26 acceptance adds exact-version User Themes v79 / 50.4 Polish localization and a selective, fingerprint-pinned Polish display-name pass for ten descriptive GNOME extensions.

Repository-only validation can be run with:

```bash
bash scripts/check-static.sh
python3 scripts/validate-repository.py
```

The historical clean-room result and environment-specific SKIP interpretation are documented in [`docs/CLEAN-ROOM-RESTORE-REPORT.md`](docs/CLEAN-ROOM-RESTORE-REPORT.md).

## Limitations

This repository is a reproducible rebuild definition, not a full-disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, Tailscale node identity, and private signing material remain outside Git.

## Maintenance

Fedora major-version changes follow the controlled lifecycle in [`docs/UPGRADE.md`](docs/UPGRADE.md): target-release repository review, clean-room validation, physical upgrade, full verifier acceptance, and only then baseline promotion.

After material Fedora, GNOME, kernel/NVIDIA, extension, localization, restore, or security-policy changes:

1. run repository static validation;
2. run the full physical-host verifier;
3. repeat clean-room restore testing when the restore path or supported baseline changes;
4. update the documented accepted baseline only after those checks pass.
