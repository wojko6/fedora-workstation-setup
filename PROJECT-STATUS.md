# Project Status

**Status:** Physical baseline refreshed and accepted 2026-09-21; Recovery and Stability Gates passed; 2026-09-21 localization closure accepted; latest private DR generation integrity-verified; full physical verifier clean

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

After the 2026-09-21 localization closure, the physical-workstation verifier was rerun from the canonical repository checkout and completed with:

```text
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current complete accepted physical-host aggregate for the Fedora 44 / GNOME 50.5 desired state. It includes the accepted 2026-09-21 localization additions for Blur my Shell, Clipboard Indicator, Extension Manager, Helium, and GNOME Tweaks. Ptyxis 50.1 remains repository-managed, Bluetooth Battery Meter v49 remains both the active runtime and reproducible restore pin, and the private GNOME Weather custom location remains reproducibly verified through libgweather without publishing its identifying data. No warnings, failures, or environment skips remain in the physical acceptance run.

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
- reviewed GNOME Weather custom-location state restored through libgweather serialization;
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
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
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

Bluetooth Battery Meter uses a minimal **16-entry** completion overlay for the BudsLink Companion preferences page. The desired-state restore lock is now v49; the localization installer and verifier retain compatibility with the previously audited v46 build while requiring the audited gettext domain and exact BudsLink source messages. The v49 installation passed its dedicated verifier and gettext smoke test, and the completed preferences page was visually confirmed in Polish after terminating the resident Extension Manager and GNOME Extensions processes that had cached the previous catalog.

Vitals v85 uses a version-pinned completion overlay over its incomplete upstream Polish catalog. ddterm v72 uses a one-entry gettext completion plus a localized metadata description for its About window.

Advanced Media Controller v31 / 6.5 ships no Polish catalog in the tested archive. The repository carries a complete **276-entry** Polish gettext catalog generated against the exact v31 string template. Its installer/verifier checks version 31, version name 6.5, gettext domain, audited file fingerprints, translation completeness, byte-for-byte installed `.mo` equality, and a runtime gettext smoke test requiring `General` to resolve to `Ogólne`. The preferences UI was visually confirmed in Polish on the physical workstation.

Papers 49.8 uses a minimal completion overlay for the Nautilus document-properties provider, the `No Annotations` status page, and the empty start page. The completed catalog was installed and matched the repository-managed overlay, and all three affected UI areas were visually confirmed in Polish.

`scripts/install-localizations.sh` now invokes 15 version-specific GNOME-extension localization installers plus six application/system localization stages: Papers, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks. Dedicated localization verifiers are integrated into the main `scripts/verify.sh`. The current complete physical-host verifier is accepted at `PASS=236 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`.

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

The physical workstation was running GNOME Shell 50.5 during the final acceptance run. After the final Ptyxis and Bluetooth Battery Meter v49 updates, the complete live verifier finished with `PASS=228 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`, establishing the accepted 2026-09-20 physical baseline at that checkpoint. The historical clean-room VM result remains `PASS=147 WARN=0 FAIL=0 SKIP=8` on Fedora 44 / GNOME 50.4.

## Bluetooth Battery Meter BudsLink localization — 2026-09-20

The active physical installation reports Bluetooth Battery Meter **v49**, and the reproducible extension lock and inventory have now been promoted to v49. Commit `9812dd7` updated the localization tooling to support both builds without silently accepting other versions. The repository overlay completes all **16** untranslated BudsLink Companion messages and preserves a separate pre-completion catalog backup for each supported version.

The physical v49 installer and dedicated verifier completed successfully:

```text
Completion entries: 16
PASS: Bluetooth Battery Meter v49 BudsLink Polish localization matches repository completion
PASS: Bluetooth Battery Meter v49 BudsLink Polish completion installed
```

A direct gettext smoke test resolved `Enable BudsLink integration` to `Włącz integrację z BudsLink`. The initially unchanged UI was traced to resident Extension Manager and GNOME Extensions application-service processes caching the old catalog. After those processes were terminated and the preferences were reopened, the BudsLink page was visually confirmed in Polish.

The localization implementation and runtime result are accepted. The exact EGO v49 archive was validated as UUID `Bluetooth-Battery-Meter@maniacx.github.com`, runtime version 49, and pinned with SHA-256 `53efe7719a55376ba7fdcaf5a837ec3567804489d39446f26bec881e85dd5afc`. The inventory and restore lock now match the physical v49 state.

## GNOME Weather private custom location — 2026-09-20

GNOME Weather 50.0 did not expose one reviewed private location reliably through its normal search, so the project gained a reproducible custom-location mechanism without keeping the real place name or coordinates in public Git.

The public repository contains only `gnome/weather-locations.example.tsv`. Real location data belongs in the gitignored `gnome/weather-locations.local.tsv` and must be restored separately from a private backup.

Physical testing exposed two useful failure modes before promotion: an incorrect coordinate-unit conversion produced implausible temperatures, and a later correction could coexist with an older same-name entry. Both issues were fixed. The manager normalizes reviewed entries by name, installs one detached libgweather location using decimal-degree coordinates, and verifies geographical equivalence through the public libgweather API instead of comparing private serialized bytes.

The integration is part of normal restore and verification when the local private file is present:

```text
install.sh
  -> scripts/restore-gnome.sh
  -> scripts/install-weather-locations.sh
  -> scripts/manage-weather-locations.py --config gnome/weather-locations.local.tsv --apply

scripts/verify.sh
  -> scripts/manage-weather-locations.py --config gnome/weather-locations.local.tsv --verify
```

`gnome-weather` and `python3-gobject` are explicit RPM desired-state dependencies. Repository consistency validation checks the anonymized public example, while the real location remains outside Git. At the GNOME Weather integration checkpoint, the full physical-host verifier completed successfully with `PASS=231 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0` while the private location file was present. The current project-wide accepted aggregate is documented separately below.

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

## 2026-09-21 localization and disaster-recovery closure

The physical localization work was closed with a fresh full verifier run from the canonical checkout:

```text
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

The final GNOME Tweaks 49.0 terminology override was visually confirmed as `Hinting` → `Dopasowanie do pikseli`. VSCodium remains intentionally deferred and is not claimed as reproducibly localized.

A new private offline disaster-recovery generation dated **2026-09-21** was then created after the clean verifier result. It contains compressed read-only Btrfs streams for root, home, and the separate `/var/lib/machines` subvolume, plus `/boot`, EFI, and reconstruction metadata. Zstandard integrity tests passed, and the final 21-entry `SHA256SUMS` manifest was verified with `SHA256_VERIFY_RC=0`. The private artifacts and machine identifiers remain outside Git.

## D-H1 trusted firewalld boundary — implementation state

The P0.1 / D-H1 code change is implemented and repository-tested, but is **not yet physically accepted** on the workstation.

Implemented controls:

- a physical restore requires an explicitly reviewed `TRUSTED_WIFI_UUID` before setup stages begin;
- the active/default-route connection must be Wi-Fi and its NetworkManager UUID must match the reviewed UUID;
- optional `TRUSTED_WIFI_PROFILE` can additionally pin the profile name;
- an untrusted UUID is rejected before NetworkManager/firewalld mutation;
- `workstation-kdeconnect` is converged to exact state with only `dhcpv6-client`, `mdns`, and `kdeconnect`;
- `ssh`, forwarding, masquerade, explicit ports/protocols/sources, forward/source ports, ICMP blocks, ICMP inversion, and rich rules are removed;
- KDE Connect exposure in another active zone causes a fail-closed rejection;
- previous profile/zone state is captured and rollback is attempted on configuration failure;
- virtualized clean-room environments without a trusted physical Wi-Fi profile receive an explicit environment `SKIP`.

Negative/positive mock fixtures are integrated into `scripts/check-static.sh`: an untrusted UUID must fail with zero mutation, while a deliberately dirty trusted zone must converge to the minimal exact-state policy.

Physical-host acceptance is still required before D-H1 can be marked closed.

## Repository validation

Repository-only validation is automated through `scripts/check-static.sh`, which is used both locally and by GitHub Actions. It covers Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON validation, and desired-state inventory consistency.

The live-system verifier is:

```bash
bash scripts/verify.sh
```

`FAIL` means required state is not satisfied. `WARN` means an actionable mismatch requires review. `SKIP` is used only for documented environment-specific exclusions.

## Current confidence

The repository has passed a clean-room functional restore test for Fedora 44 / GNOME 50.4 and a zero-warning, zero-failure physical-host verification on the Fedora 44 / GNOME 50.5 workstation after the accepted security, networking, extension, system-localization, GNOME Weather, and 2026-09-21 localization changes. The current complete physical-host aggregate is `PASS=236 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`. The managed Helium and GNOME Tweaks fixes are physically accepted, the GNOME Tweaks `Hinting` override is visually confirmed, Bluetooth Battery Meter v49 is source-pinned with its validated EGO archive, and the private Weather location remains part of the verified local desired state without publishing its identifying data.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, Tailscale node identity, private signing keys, and other private state must be restored separately.

## Remaining work

The next engineering block is security/architecture hardening, followed by routine lifecycle maintenance:

- **D-H1 (implemented, physical acceptance pending):** apply the new trusted-UUID/exact-state firewalld policy on the physical workstation and verify the live result;
- **D-H2:** expand explicit verifier coverage for security controls such as SELinux/AVC state, disabled SSH service/socket state, kernel lockdown, listener/firewall state, and expected external-module signing evidence;
- **D-H3:** make remaining required-state checks consistently fail-closed/strict, including desired Flatpak state;
- **D-H4:** verify installed GNOME-extension tree integrity so same-version source tampering cannot be silently accepted;
- introduce LUKS during a future controlled reinstall/restore if full-disk encryption is desired; in-place conversion remains intentionally deferred;
- keep package and GNOME extension pins current as Fedora evolves;
- repeat the clean-room restore test after material restore-path or supported-baseline changes;
- keep private machine-specific configuration and signing material separate from the public repository;
- rerun physical-host verification after material desired-state changes, especially kernel/NVIDIA updates;
- re-audit version-pinned localization whenever an extension or application version changes;
- keep VSCodium localization explicitly deferred until it is intentionally brought into scope;
- test future Fedora/GNOME 51 changes in a VM before promoting them to the physical workstation.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; the detailed total-failure operational sequence is documented in `docs/DISASTER-RECOVERY-RUNBOOK.md`. These complement rather than replace the repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when required packages, repositories, GNOME extensions, schemas, curated GNOME state, localization artifacts, required services, selected security controls, Secure Boot/NVIDIA signing state, and network/firewalld policy all match the documented desired state, while private data remains outside the public repository.

`scripts/verify.sh` must report zero `WARN` and zero `FAIL` on the validated physical target.

**Last complete accepted physical aggregate: `PASS=236 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`.**
