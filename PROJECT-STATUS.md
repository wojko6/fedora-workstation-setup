# Project Status

**Status:** Clean-room restore validated; physical workstation desired state accepted  
**Baseline:** Fedora 44 · GNOME Shell 50.4 · Wayland  
**Validation environments:** Oracle VirtualBox clean-room VM and physical Lenovo Legion 5 15ACH6H

## Objective

This repository defines a reproducible desired state for a Fedora workstation. The goal is to rebuild the workstation after a clean Fedora installation without restoring an opaque system image and without storing private user data in Git.

## Validation results

The restore workflow was exercised against a clean Fedora 44 virtual machine and verified after the guest was fully updated to GNOME Shell 50.4.

Clean-room VM result:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

The eight `SKIP` results are intentional environment-specific exclusions rather than unresolved warnings.

After post-restore maintenance, security hardening, Secure Boot enablement, the 2026-09-17 GNOME extension compatibility refresh, completion of the accepted Polish localization work, removal of NordVPN from desired state, and restore-tool dependency cleanup, the current desired state was verified on the physical Fedora workstation:

```text
PASS=218 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current accepted physical-host baseline.

## Current accepted state

The physical-host validation includes:

- required RPM packages and external repositories;
- Tailscale package and `tailscaled` service state;
- disabled LLMNR and disabled GNOME/GVfs WS-Discovery;
- `kernel.kptr_restrict=1` in persistent and runtime state;
- Secure Boot enabled with a signed NVIDIA kernel module;
- reproducible DDC/CI support for external-monitor brightness control;
- required GNOME extensions installed and `ACTIVE`;
- compiled extension schemas where required;
- curated GNOME desired state and Dhruva dock state;
- Wi-Fi persisted to firewalld's `public` zone and the active interface attached to the same zone;
- GSConnect D-Bus integration and KDE Connect firewalld service;
- repository-managed Polish localization verification;
- extension version pinning and drift detection.

NordVPN and gNordVPN-Local are intentionally absent from the accepted state. Tailscale remains the supported overlay/VPN component tracked by this repository.

Authentication state, network identities, credentials, private signing material, Tailscale node identity, and other private state remain intentionally outside Git.

## GNOME extension compatibility refresh — 2026-09-17

A controlled extension refresh was audited on the physical Fedora 44 / GNOME 50.4 workstation before the candidate set was promoted into desired state.

Seven third-party extensions passed the runtime/compatibility checks and were accepted: ArcMenu, Bluetooth Battery Meter, Caffeine, Freon, GSConnect, Tiling Shell, and User Themes. Media Controls was removed because the installed release did not declare GNOME 50 compatibility. Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks.

GSConnect validation included the shell extension runtime, user D-Bus registration and introspection, and the `kdeconnect` service in the active Wi-Fi firewalld `public` zone. Phone-side Tailscale split-tunneling policy remains intentionally outside Fedora desired state.

The refresh also corrected reproducibility details discovered by physical testing: extension inventory paths are normalized to `~/.local/...`, inventory rows are deterministic and UUID-deduplicated, legitimate live-state changes were reviewed before acceptance, and extension restore now detects version drift rather than accepting any installed copy.

Full details are recorded in `docs/gnome-extension-audit-2026-09-17.md`.

## Security validation

The physical workstation security review established and validated the following controls:

- systemd-resolved LLMNR disabled globally;
- GNOME/GVfs WS-Discovery disabled while required mDNS remains available;
- `kernel.kptr_restrict=1` persistent and active;
- Wi-Fi persistently assigned to firewalld's `public` zone;
- SSH server disabled/inactive;
- SELinux enforcing;
- Secure Boot enabled;
- local akmods signing certificate enrolled through MOK;
- NVIDIA kernel module signed and operational under Secure Boot;
- kernel lockdown active in integrity mode;
- controlled package-update workflow retained instead of unattended full-system upgrades.

A material NVIDIA/akmods update was exercised during validation. The workstation remained operational after the update and reboot, with Secure Boot and the signed NVIDIA path still working.

### Deferred security item

The current Fedora system partition is Btrfs without a LUKS layer. Full-disk encryption is therefore not claimed by this project. A future controlled reinstall/restore is the preferred point to introduce LUKS rather than attempting risky in-place conversion.

## Reproducible Polish GNOME localization

The repository carries localization only where upstream Polish support is missing, incomplete for the tested version, or user-visible strings are not exposed through a usable Polish gettext path.

Accepted repository-managed targets currently include:

- Desktop Icons NG (DING);
- Brightness control using ddcutil;
- Just Another Search Bar;
- Monitor Smart Saver;
- Dhruva;
- Background Logo;
- Browser Switcher;
- GSConnect v72 completion plus Shell gettext-domain fix;
- Tiling Shell v76 / 17.3 completion overlay;
- Just Perfection v37;
- Spotlight v14 / 2026.11;
- Space Bar v39.

Dhruva remains the largest localization case: a 393-message gettext catalog, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

GSConnect v72 was audited against its exact upstream catalog. Eleven untranslated entries were completed, and runtime testing identified the missing metadata `gettext-domain` required for Shell-side Quick Settings translations.

Tiling Shell v76 / 17.3 was audited against the exact installed version. Fifteen untranslated Polish strings were completed with a minimal version-pinned overlay.

Just Perfection v37 is pinned to the tested extension version and includes repository translation coverage for strings missing from the stale upstream template.

Spotlight v14 / 2026.11 does not ship a localization implementation in the audited upstream release, so the repository adds controlled gettext wiring and version-pinned source patches.

Space Bar v39 also lacks a usable upstream localization path for the audited release. The repository therefore applies an exact-version controlled localization patch over the audited v39 files. Its dedicated installer/verifier covers **109 translated source patterns** across preferences, custom-style dialogs, keyboard-shortcut dialogs, and the runtime panel menu. The physical-host installer and dedicated verifier both passed, and the translated UI was confirmed working before acceptance.

All dedicated localization checks are integrated into the main restore/verification flow only after physical validation.

## Important reproducibility decisions

- Dhruva is the canonical dock.
- GNOME `favorite-apps` is audit-only; restore does not force icon order.
- Dhruva dock order and application-folder state are restored separately from GNOME favorites.
- Extension restore is version-aware and reinstalls pinned archives on drift.
- Restore does not run the final verifier in the same GNOME session; a logout/login or reboot is required first.
- Firewalld policy follows the active/default-route network interface instead of blindly assuming the global default zone.
- Android-side Tailscale/KDE Connect split-tunneling is documented but not managed by Fedora automation.
- Third-party extensions remain authored and licensed by their upstream projects; this repository owns only the integration, configuration, localization overlays, validation, and documentation it adds.

## Repository validation

Repository-only validation is automated through `scripts/check-static.sh`, which is used both locally and by GitHub Actions. It covers Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON validation, and desired-state inventory consistency.

The live-system verifier is:

```bash
bash scripts/verify.sh
```

`FAIL` means required state is not satisfied. `WARN` means an actionable mismatch requires review. `SKIP` is used only for documented environment-specific exclusions.

## Current confidence

The repository has passed a clean-room functional restore test for Fedora 44 / GNOME 50.4 and a zero-warning, zero-failure verification on the physical workstation after the accepted security, networking, extension, and localization changes.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, Tailscale node identity, private signing keys, and other private state must be restored separately.

## Remaining work

The remaining work is maintenance plus one explicitly deferred security decision:

- introduce LUKS during a future controlled reinstall/restore if full-disk encryption is desired;
- keep package and GNOME extension pins current as Fedora evolves;
- repeat the clean-room restore test after major Fedora/GNOME changes;
- keep private machine-specific configuration and signing material separate from the public repository;
- rerun physical-host verification after material desired-state changes, especially kernel/NVIDIA updates;
- continue auditing accepted extensions for upstream Polish coverage and maintain repository translations only where a demonstrated gap exists;
- test future Fedora/GNOME 51 changes in a VM before promoting them to the physical workstation.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; it complements rather than replaces this repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when required packages, repositories, GNOME extensions, schemas, curated GNOME state, localization artifacts, required services, selected security controls, Secure Boot/NVIDIA signing state, and network/firewalld policy all match the documented desired state, while private data remains outside the public repository.

`scripts/verify.sh` must report zero `WARN` and zero `FAIL` on the validated physical target.

**Current result: ACCEPTED (`PASS=218 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`).**
