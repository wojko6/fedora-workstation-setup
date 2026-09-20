# Project Status

**Status:** Physical baseline refreshed 2026-09-20; Recovery and Stability Gates passed; Ptyxis main-menu localization visually accepted; full verifier rerun and Bluetooth Battery Meter v49 source-pin follow-ups open

**Baseline:** Fedora 44 · GNOME Shell 50.5 · Wayland

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

After the 2026-09-20 system-localization work for Papers 49.8, Plymouth offline updates, and Ptyxis 50.1 was integrated, and the host had advanced to GNOME Shell 50.5, the current physical-workstation verifier run completed with:

```text
PASS=231 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the last complete accepted physical-host aggregate for the Fedora 44 / GNOME 50.5 desired state. Later Bluetooth Battery Meter v49 localization work passed its dedicated verifier and visual acceptance test but has not yet been followed by another complete physical-host verifier run. The subsequently expanded Ptyxis 50.1 main-window/menu catalog has now been installed, passed its dedicated verifier, and was visually confirmed in Polish on the physical workstation; it is not yet covered by a fresh complete aggregate.

## Current desired state

The physical-host desired state includes:

- required RPM packages and external repositories;
- Tailscale package and `tailscaled` service state;
- disabled LLMNR and disabled GNOME/GVfs WS-Discovery;
- `kernel.kptr_restrict=1` in persistent and runtime state;
- Secure Boot enabled with a signed NVIDIA kernel module;
- reproducible DDC/CI support for external-monitor brightness control;
- required GNOME extensions installed and `ACTIVE`;
- compiled extension schemas where required;
- curated GNOME desired state and Dhruva dock state;
- Wi-Fi persisted to the dedicated firewalld `workstation-kdeconnect` zone and the active interface attached to the same zone;
- GSConnect D-Bus integration and KDE Connect firewalld service;
- repository-managed Polish localization verification;
- extension version pinning and drift detection;
- fail-closed source locking for enabled user extensions, including SHA-256 pins for EGO archives and an exact GitHub commit pin for Dhruva;
- strict JSON metadata validation for EGO and pinned GitHub extension sources.

NordVPN, gNordVPN-Local, and Freon are intentionally absent from the current desired state. Tailscale remains the supported overlay/VPN component tracked by this repository.

Advanced Media Controller v31 / 6.5 is now a required user extension in desired state. Its exact runtime version and complete Polish localization are version-pinned and verified by repository tooling.

Window List was removed from desired state on 2026-09-19 after the Fedora package was removed. gNordVPN-Local is intentionally out of scope because NordVPN is not installed; Tailscale remains the supported overlay/VPN component tracked by this repository.

Authentication state, network identities, credentials, private signing material, Tailscale node identity, and other private state remain intentionally outside Git.

## GNOME extension compatibility refresh — 2026-09-17

A controlled extension refresh was audited on the physical Fedora 44 / GNOME 50.4 workstation before the candidate set was promoted into desired state.

ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes remain in the continuing desired state from that refresh. Freon also passed the compatibility test but was subsequently removed by design. Media Controls was removed because the installed release did not declare GNOME 50 compatibility. Dash2Dock Animated was removed because Dhruva is the canonical dock and running both produced duplicate docks.

Advanced Media Controller v31 / 6.5 was added later after physical compatibility and localization testing.

GSConnect validation included the shell extension runtime, user D-Bus registration and introspection, and the `kdeconnect` service in the dedicated active Wi-Fi firewalld `workstation-kdeconnect` zone. Phone-side Tailscale split-tunneling policy remains intentionally outside Fedora desired state.

The refresh also corrected reproducibility details discovered by physical testing: extension inventory paths are normalized to `~/.local/...`, inventory rows are deterministic and UUID-deduplicated, legitimate live-state changes were reviewed before acceptance, and extension restore detects version drift rather than accepting any installed copy.

Full details are recorded in `docs/gnome-extension-audit-2026-09-17.md`.

## Recovery Hardening Gate

The Recovery Hardening Gate has been completed.

Completed validation improvements:

- Fedora 44 version preflight validation before system changes
- GNOME Shell 50 major version validation before system changes
- required setup stage fail-closed validation
- deterministic Wi-Fi power-save handling with automatic profile detection
- explicit virtualization handling for environments without physical Wi-Fi devices

The setup pipeline now validates the supported baseline before executing changes and refuses to continue when required stages are missing or unreadable.

Final physical-host verification:

```text
PASS=231 WARN=0 FAIL=0 SKIP=0
```

## Security validation

The physical workstation security review established and validated the following controls:

- systemd-resolved LLMNR disabled globally;
- GNOME/GVfs WS-Discovery disabled while required mDNS remains available;
- `kernel.kptr_restrict=1` persistent and active;
- Wi-Fi persistently assigned to the dedicated firewalld `workstation-kdeconnect` zone;
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

Repository-managed targets currently include:

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
- Spotlight v15 / 2026.15;
- Space Bar v39;
- Bluetooth Battery Meter v46/v49 BudsLink Companion completion overlay;
- Vitals v85 completion;
- ddterm v72 completion plus metadata description localization;
- Advanced Media Controller v31 / 6.5 full Polish catalog;
- Papers 49.8 completion overlay for Nautilus document properties, annotations, and the empty start page;
- Plymouth offline-update Polish locale persistence in initramfs;
- Ptyxis 50.1 Polish main-window/menu completion plus the existing libadwaita About-dialog integration.

Dhruva remains the largest localization case: a 393-message gettext catalog, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

GSConnect v72 was audited against its exact upstream catalog. Eleven untranslated entries were completed, and runtime testing identified the missing metadata `gettext-domain` required for Shell-side Quick Settings translations.

Tiling Shell v76 / 17.3 was audited against the exact installed version. Fifteen untranslated Polish strings were completed with a minimal version-pinned overlay.

Just Perfection v37 is pinned to the tested extension version and includes repository translation coverage for strings missing from the stale upstream template.

Spotlight v15 / 2026.15 does not ship a localization implementation in the audited upstream release, so the repository adds controlled gettext wiring and version-pinned source patches.

Space Bar v39 lacks a usable upstream localization path for the audited release. The repository applies an exact-version controlled localization patch covering 109 translated source patterns across preferences, custom-style dialogs, keyboard-shortcut dialogs, and the runtime panel menu.

Bluetooth Battery Meter uses a minimal **16-entry** completion overlay for the BudsLink Companion preferences page. The installer and verifier support the restore-locked v46 build and the active physical-host v49 build, while requiring the audited gettext domain and exact BudsLink source messages. The v49 installation passed its dedicated verifier and gettext smoke test, and the completed preferences page was visually confirmed in Polish after terminating the resident Extension Manager and GNOME Extensions processes that had cached the previous catalog.

Vitals v85 uses a version-pinned completion overlay over its incomplete upstream Polish catalog. ddterm v72 uses a one-entry gettext completion plus a localized metadata description for its About window.

Advanced Media Controller v31 / 6.5 ships no Polish catalog in the tested archive. The repository carries a complete **276-entry** Polish gettext catalog generated against the exact v31 string template. Its installer/verifier checks version 31, version name 6.5, gettext domain, audited file fingerprints, translation completeness, byte-for-byte installed `.mo` equality, and a runtime gettext smoke test requiring `General` to resolve to `Ogólne`. The preferences UI was visually confirmed in Polish on the physical workstation.

Papers 49.8 uses a minimal completion overlay for the Nautilus document-properties provider, the `No Annotations` status page, and the empty start page. The completed catalog was installed and matched the repository-managed overlay, and all three affected UI areas were visually confirmed in Polish.

All 12 version-specific GNOME-extension localization installers, plus the system-level Papers, Plymouth, and Ptyxis stages, are invoked by `scripts/install-localizations.sh`. Dedicated localization verifiers are integrated into the main `scripts/verify.sh`. The last complete physical-host verifier remains the accepted `PASS=231 WARN=0 FAIL=0 SKIP=0` aggregate; the later Bluetooth Battery Meter v49 completion passed its dedicated verifier and visual acceptance test.

## Important reproducibility decisions

- Dhruva is the canonical dock.
- GNOME `favorite-apps` is audit-only; restore does not force icon order.
- Dhruva dock order and application-folder state are restored separately from GNOME favorites.
- Extension restore is version-aware and reinstalls pinned archives on drift.
- Restore does not run the final verifier in the same GNOME session; a logout/login or reboot is required first.
- Firewalld policy follows the active/default-route network interface instead of blindly assuming the global default zone.
- Android-side Tailscale/KDE Connect split-tunneling is documented but not managed by Fedora automation.
- Third-party extensions remain authored and licensed by their upstream projects; this repository owns only the integration, configuration, localization overlays, validation, and documentation it adds.

## End-of-day stability closure — 2026-09-19

The 2026-09-19 Recovery and Stability Gates were completed without unresolved warnings or failures. Recovery pipeline review found that Background Logo, Browser Switcher, and Dhruva installers existed but were not connected to the main localization pipeline; all three were added to the localization pipeline. At that checkpoint, the pipeline contained 11 version-specific localization installers. Repository consistency passed with 26 enabled extensions and 26 inventory rows. The final physical-host verifier completed with `PASS=226 WARN=0 FAIL=0 SKIP=0`. GNOME Keyring i18n verification completed with `PASS=7 WARN=0 FAIL=0`. Final `git diff --check` was clean and the repository was synchronized with `origin/main`.

## Physical baseline refresh — 2026-09-20

System-level Polish localization was extended and made reproducible for Papers 49.8 / Nautilus document properties, Papers annotations and empty start page, Plymouth offline updates, and Ptyxis 50.1. Papers received a minimal completion overlay, Plymouth's existing Polish catalog and locale data were persisted into initramfs through dracut, and Ptyxis initially received a minimal main gettext-domain bridge that activated libadwaita's existing Polish About-dialog translations. A later physical UI audit found the primary Ptyxis menu still falling back to English, so the repository catalog was expanded to cover the audited main-window/menu messages. The expanded catalog was installed, the dedicated verifier passed, and the restarted Ptyxis menu was visually confirmed in Polish on the physical workstation.

The physical workstation was running GNOME Shell 50.5 during the final acceptance run. The complete live verifier finished with `PASS=231 WARN=0 FAIL=0 SKIP=0`, establishing the new current physical baseline. The historical clean-room VM result remains `PASS=147 WARN=0 FAIL=0 SKIP=8` on Fedora 44 / GNOME 50.4.

## Bluetooth Battery Meter BudsLink localization — 2026-09-20

The active physical installation reports Bluetooth Battery Meter **v49**, while the reproducible extension lock and inventory still record v46. Commit `9812dd7` updated the localization tooling to support both builds without silently accepting other versions. The repository overlay completes all **16** untranslated BudsLink Companion messages and preserves a separate pre-completion catalog backup for each supported version.

The physical v49 installer and dedicated verifier completed successfully:

```text
Completion entries: 16
PASS: Bluetooth Battery Meter v49 BudsLink Polish localization matches repository completion
PASS: Bluetooth Battery Meter v49 BudsLink Polish completion installed
```

A direct gettext smoke test resolved `Enable BudsLink integration` to `Włącz integrację z BudsLink`. The initially unchanged UI was traced to resident Extension Manager and GNOME Extensions application-service processes caching the old catalog. After those processes were terminated and the preferences were reopened, the BudsLink page was visually confirmed in Polish.

The localization implementation and runtime result are accepted. Updating the extension archive pin and inventory from v46 to a validated v49 source remains a separate reproducibility task; until that is completed, the v49 host state is newer than the repository's extension-install lock.

## Extension supply-chain hardening — 2026-09-20

H3 and L2 have been implemented and locally validated.

All 21 current extensions.gnome.org user-extension archives are recorded in `gnome/extensions-lock.tsv` with SHA-256 pins. The restore path verifies the digest before extraction and strictly parses `metadata.json`, rejecting checksum mismatch, malformed or duplicate-key JSON, UUID mismatch, runtime-version mismatch, and missing GNOME Shell 50 compatibility.

Dhruva remains pinned to exact upstream commit:

```text
f8121f68fcef48c0324e8cd87fd30bf9a2131962
```

Its GitHub metadata path now uses strict JSON validation and deterministic metadata preparation instead of grep/sed/regex parsing.

Real-source local validation completed with:

```text
REAL_EGO_PASS=21
REAL_EGO_FAIL=0
REAL DHRUVA SOURCE: PASS
```

Negative fixture suites also passed for invalid SHA-256, UUID mismatch, malformed JSON, duplicate JSON keys, runtime-version mismatch, invalid version type, and missing GNOME Shell compatibility.

Current status:

```text
H3: CLOSED
L2: CLOSED
```

Implementation commit `9299954b0b902943df2520d03bf40a87874c7f00` passed GitHub Actions Static checks run #132. Documentation closure commit `85328d0f5c5614c4f9c28f880d79165b85fc3108` passed run #133.

## Repository validation

Repository-only validation is automated through `scripts/check-static.sh`, which is used both locally and by GitHub Actions. It covers Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON validation, and desired-state inventory consistency.

The live-system verifier is:

```bash
bash scripts/verify.sh
```

`FAIL` means required state is not satisfied. `WARN` means an actionable mismatch requires review. `SKIP` is used only for documented environment-specific exclusions.

## Current confidence

The repository has passed a clean-room functional restore test for Fedora 44 / GNOME 50.4 and a zero-warning, zero-failure physical-host verification on the Fedora 44 / GNOME 50.5 workstation after the accepted security, networking, extension, and system-localization changes. The last complete physical-host aggregate is `PASS=231 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`. The later Bluetooth Battery Meter v49 localization passed its dedicated verifier and visual acceptance test; however, the repository still restores v46, so the active v49 extension build is not yet fully reproducible from the recorded source lock.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, Tailscale node identity, private signing keys, and other private state must be restored separately.

## Remaining work

Routine maintenance remains plus one explicitly deferred security decision:

- introduce LUKS during a future controlled reinstall/restore if full-disk encryption is desired;
- keep package and GNOME extension pins current as Fedora evolves;
- repeat the clean-room restore test after major Fedora/GNOME changes;
- keep private machine-specific configuration and signing material separate from the public repository;
- rerun physical-host verification after material desired-state changes, especially kernel/NVIDIA updates;
- update the Bluetooth Battery Meter archive pin and inventory from v46 to the validated v49 source before declaring the v49 extension build fully reproducible;
- rerun the full physical-host verifier after the accepted Ptyxis 50.1 main-window/menu localization change;
- re-audit version-pinned localization whenever an extension version changes;
- test future Fedora/GNOME 51 changes in a VM before promoting them to the physical workstation.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; it complements rather than replaces this repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when required packages, repositories, GNOME extensions, schemas, curated GNOME state, localization artifacts, required services, selected security controls, Secure Boot/NVIDIA signing state, and network/firewalld policy all match the documented desired state, while private data remains outside the public repository.

`scripts/verify.sh` must report zero `WARN` and zero `FAIL` on the validated physical target.

**Last complete accepted physical aggregate: `PASS=231 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`.**
