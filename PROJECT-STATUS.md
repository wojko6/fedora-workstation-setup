# Project Status

**Status:** Physical baseline refreshed and accepted 2026-09-24; Recovery and Stability Gates passed; GSConnect v73 and ddterm v73 localization promotion physically accepted; dedicated `workstation-tailscale` DROP policy physically accepted; D-H1, D-H2/D-H3, and D-H4 High-severity audit remediation physically accepted; reproducible DING System Monitor desktop-menu integration physically accepted; unused desktop applications removed from desired state; Helium required in desired state; VPCS COPR restricted to vpcs; Firefox explicitly absent; MOK signer verification made deterministic; external repository trust anchors and package signer identities physically accepted; latest private DR generation integrity-verified; full physical verifier clean at PASS=256 WARN=0 FAIL=0 SKIP=0

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

After the 2026-09-24 GSConnect/ddterm v73 localization promotion, Tailscale runtime-target verifier portability fix, and restoration of the accepted Dhruva dock order, the physical-workstation verifier was rerun from the audit branch and completed with:

```text
PASS=256 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current complete accepted physical-host aggregate for the Fedora 44 / GNOME 50.5 desired state. It includes GSConnect v73 and ddterm v73 localization, the dedicated `workstation-tailscale` DROP policy, D-H1 trusted-firewall controls, D-H2/D-H3 explicit fail-closed security verification, D-H4 deterministic whole-tree integrity verification for every enabled user GNOME extension, and the repository-managed DING System Monitor desktop-menu customization. Ptyxis 50.1 is repository-managed and its in-application Polish UI is visually accepted, while three GNOME Shell launcher actions (`New Window`, `New Tab`, `Preferences`) remain a documented `.desktop` localization gap; Bluetooth Battery Meter v49 remains both the active runtime and reproducible restore pin, and the private GNOME Weather custom location remains reproducibly verified through libgweather without publishing its identifying data. No warnings, failures, or environment skips remain in the physical acceptance run.

## Current desired state

The physical-host desired state includes:

- required RPM packages and external repositories;
- Tailscale package and `tailscaled` service state;
- dedicated `workstation-tailscale` firewalld exact-state policy for `tailscale0` (`DROP`, no services/ports/forwarding/masquerade);
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
- deterministic whole-tree SHA-256 integrity locks for all 22 enabled user extensions, with same-version drift detection and restore enforcement;
- a version-pinned DING v97 desktop-menu customization that adds `Monitor systemu`, launches `org.gnome.SystemMonitor.desktop`, is restored by `install.sh`, verified explicitly, and is covered by the D-H4 tree lock;
- `gnome-system-monitor` as an explicit RPM desired-state dependency;
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
- Wi-Fi persistently assigned to the dedicated firewalld `workstation-kdeconnect` zone with trusted-UUID gating and exact-state policy (`dhcpv6-client`, `mdns`, `kdeconnect` only);
- OpenSSH server package absent; `openssh-clients` retained for outbound SSH;
- SELinux enforcing;
- Secure Boot enabled;
- local akmods signing certificate enrolled through MOK;
- NVIDIA kernel module signed and operational under Secure Boot;
- kernel lockdown active in integrity mode;
- controlled package-update workflow retained instead of unattended full-system upgrades;
- explicit live security-posture verification is integrated into the main verifier;
- required desired-state checks are fail-closed, including RPMs, external repositories, Tailscale, Flatpak applications, Wi-Fi/security state, and zero-WARN final acceptance.

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
- GSConnect v73 20-entry managed catalog plus Shell/RunCommand gettext-domain fixes and localized factory RunCommand names;
- Tiling Shell v76 / 17.3 completion overlay;
- Just Perfection v37;
- Spotlight v15 / 2026.15;
- Space Bar v39;
- Bluetooth Battery Meter v46/v49 BudsLink Companion completion overlay;
- Vitals v85 completion;
- ddterm v73 18-entry completion plus metadata description localization;
- Advanced Media Controller v31 / 6.5 full Polish catalog;
- Papers 49.8 completion overlay for Nautilus document properties, annotations, and the empty start page;
- Plymouth offline-update Polish locale persistence in initramfs, physically and visually validated during a real offline-update cycle on 2026-09-22;
- Ptyxis 50.1 Polish main-window/menu completion plus the existing libadwaita About-dialog integration.

Dhruva remains the largest localization case: a 393-message gettext catalog, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

GSConnect v73 was audited against its exact upstream release. The catalog itself has 12 untranslated entries, including the new v73 `Target Device Name` gap, and the missing metadata `gettext-domain` repair remains required for the Shell-side catalog. A post-login visual check on 2026-09-24 exposed two additional unextracted plugin strings, bringing the audited gap set to 14. A subsequent RunCommand audit found that the command-editor GtkBuilder resource omits the GSConnect gettext domain and that five factory command names are stored as English GSettings data rather than gettext strings. The branch now manages 20 catalog entries, patches the process default gettext domain through exact-version `utils/setup.js`, and safely localizes only the five exact factory `name` fields while preserving the command lines. The corrected physical installer/verifier pass completed successfully with all five factory names localized and all RunCommand gettext checks passing. The final GSConnect v73 tree hash is `29bd02e3021fea0146311a623c3cd937dd96b224c41aeb83449d530f3468bffa`.

Tiling Shell v76 / 17.3 was audited against the exact installed version. Fifteen untranslated Polish strings were completed with a minimal version-pinned overlay.

Just Perfection v37 is pinned to the tested extension version and includes repository translation coverage for strings missing from the stale upstream template.

Spotlight v15 / 2026.15 does not ship a localization implementation in the audited upstream release, so the repository adds controlled gettext wiring and version-pinned source patches.

Space Bar v39 lacks a usable upstream localization path for the audited release. The repository applies an exact-version controlled localization patch covering 109 translated source patterns across preferences, custom-style dialogs, keyboard-shortcut dialogs, and the runtime panel menu.

Bluetooth Battery Meter uses a minimal **16-entry** completion overlay for the BudsLink Companion preferences page. The desired-state restore lock is now v49; the localization installer and verifier retain compatibility with the previously audited v46 build while requiring the audited gettext domain and exact BudsLink source messages. The v49 installation passed its dedicated verifier and gettext smoke test, and the completed preferences page was visually confirmed in Polish after terminating the resident Extension Manager and GNOME Extensions processes that had cached the previous catalog.

Vitals v85 uses a version-pinned completion overlay over its incomplete upstream Polish catalog. ddterm v73 now uses a full 18-entry completion for all audited fuzzy/untranslated catalog gaps plus the localized metadata description for its About window; the dedicated v73 installer/verifier passed on the physical workstation on 2026-09-24.

Advanced Media Controller v31 / 6.5 ships no Polish catalog in the tested archive. The repository carries a complete **276-entry** Polish gettext catalog generated against the exact v31 string template. Its installer/verifier checks version 31, version name 6.5, gettext domain, audited file fingerprints, translation completeness, byte-for-byte installed `.mo` equality, and a runtime gettext smoke test requiring `General` to resolve to `Ogólne`. The preferences UI was visually confirmed in Polish on the physical workstation.

Papers 49.8 uses a minimal completion overlay for the Nautilus document-properties provider, the `No Annotations` status page, and the empty start page. The completed catalog was installed and matched the repository-managed overlay, and all three affected UI areas were visually confirmed in Polish.

Plymouth offline-update localization is now fully physically validated. During a real Fedora offline-update cycle on **2026-09-22**, the physical workstation displayed the update screen in Polish, including `Instalowanie aktualizacji…`, `Nie należy wyłączać komputera`, and translated progress text (`Ukończono 13%` was observed). This closes the previous evidence gap between technically verified initramfs contents and actual user-visible runtime behavior.

`scripts/install-localizations.sh` now manages 25 localization targets/operations: four generic gettext targets, 15 specialized GNOME-extension stages, and six application/system stages (Papers, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks). Dedicated localization verifiers are integrated into the main `scripts/verify.sh`. GSConnect v73 and ddterm v73 passed their dedicated physical checks and visual acceptance, and the final 2026-09-24 full physical verifier completed cleanly at `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`.

## GSConnect/ddterm v73 localization promotion — 2026-09-24

The physical workstation had independently updated GSConnect and ddterm to v73, creating controlled localization/version drift from the accepted v72 repository state. A read-only audit pinned the exact v73 upstream state before remediation. GSConnect v73 retains 11 prior untranslated messages and adds `Target Device Name`, for a 12-entry completion; its pristine metadata still omits the Shell gettext domain. ddterm v73 contains 10 fuzzy and 8 untranslated Polish catalog entries, so the prior one-entry fix was expanded to a complete 18-entry overlay while retaining the localized metadata description.

The first staged v73 installers completed successfully on the physical Fedora 44 / GNOME 50.5 workstation and both dedicated verifiers passed. The resulting ddterm tree hash remains valid, but the GSConnect hash below was later superseded when the post-login visual audit exposed two source strings missing from the upstream translation catalogs:

```text
GSConnect v73  29bd02e3021fea0146311a623c3cd937dd96b224c41aeb83449d530f3468bffa  (final RunCommand-remediated tree)
ddterm v73     dbd72752dcc7687ab7a14a36ff1780f65e0b75e71245b8fa473e833b229c0d26
```

The audit branch promotes the v73 inventory rows, exact EGO archive SHA-256 pins, and final post-localization tree locks for both ddterm and GSConnect. GSConnect v73 RunCommand names and editor were visually confirmed in Polish after logout/login, with the actual command lines unchanged. The final full physical verifier then completed at `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`, establishing the 2026-09-24 accepted baseline.

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

## D-H1 trusted firewalld boundary — CLOSED

P0.1 / D-H1 is **implemented, repository-tested, and physically accepted** on the Fedora 44 / GNOME 50.5 workstation.

Implemented and accepted controls:

- physical restore requires an explicitly reviewed `TRUSTED_WIFI_UUID` before setup stages begin;
- the active/default-route connection must be Wi-Fi and its NetworkManager UUID must match the reviewed UUID;
- optional `TRUSTED_WIFI_PROFILE` can additionally pin the profile name;
- an untrusted UUID is rejected before NetworkManager/firewalld mutation;
- `workstation-kdeconnect` converges to exact state with only `dhcpv6-client`, `mdns`, and `kdeconnect`;
- `ssh`, forwarding, masquerade, explicit ports/protocols/sources, forward/source ports, ICMP blocks, ICMP inversion, and rich rules are absent from the trusted zone;
- `kdeconnect` is removed from every other permanent firewalld zone, including the default fallback zone, without changing unrelated fallback-zone services or ports;
- previous profile/zone state is captured and rollback is exercised by repository fixtures;
- virtualized clean-room environments without a trusted physical Wi-Fi profile receive an explicit environment `SKIP`.

Repository fixtures passed for untrusted-profile zero-mutation rejection, dirty-zone exact-state convergence, cross-zone KDE Connect isolation, unrelated fallback-state preservation, and rollback restoration.

Physical acceptance evidence on 2026-09-21:

```text
saved Wi-Fi zone: workstation-kdeconnect
active interface zone: workstation-kdeconnect
runtime services: dhcpv6-client kdeconnect mdns
permanent services: dhcpv6-client kdeconnect mdns
forward: no
masquerade: no
ports/protocols/sources/rich rules: none
FedoraWorkstation: kdeconnect absent
Internet reachability: PASS (1.1.1.1 and cloudflare.com, 0% packet loss)
```

The default `FedoraWorkstation` fallback zone remains otherwise unchanged in this closure; its broader generic defaults are outside the trusted Wi-Fi exact-state policy and will be evaluated under the next explicit network/security verification work rather than changed implicitly.

## D-H2 + D-H3 security verification — CLOSED

P0.2 / D-H2 and D-H3 are **implemented, repository-tested, and physically accepted** on the Fedora 44 / GNOME 50.5 workstation.

D-H2 added explicit live verification for:

- SELinux `Enforcing` state and current-boot AVC denial detection;
- `sshd.service` and `sshd.socket` disabled/inactive state plus absence of a TCP/22 listener;
- kernel lockdown in `integrity` or stronger mode;
- NVIDIA module signature metadata and enrolled-MOK signer identity;
- trusted Wi-Fi `workstation-kdeconnect` runtime/permanent exact state, including target, services, forwarding, masquerade, ICMP inversion, explicit ports/protocols/sources, forward/source ports, ICMP blocks, rich rules, and cross-zone KDE Connect exposure.

D-H3 made required desired-state acceptance fail-closed:

- missing required RPMs now fail;
- missing required external repositories, including the VPCS COPR, now fail;
- missing/inactive Tailscale now fails;
- the Flatpak manifest and Flathub remote are verified explicitly and missing required applications fail;
- required Wi-Fi/security desired state fails instead of degrading to advisory warnings;
- the final verifier returns success only when both `FAIL=0` and `WARN=0`.

Repository fixtures cover valid physical posture and negative cases for SELinux permissive mode, current-boot AVC denials, active SSH, trusted-zone service drift, cross-zone KDE Connect exposure, unenrolled NVIDIA signer identity, runtime firewalld target handling, and systems where the akmods certificate file is not directly readable/present while the loaded module signer is verifiably enrolled.

Physical acceptance result on 2026-09-21:

```text
PASS=246 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

D-H2 status: **CLOSED / PHYSICALLY ACCEPTED**.

D-H3 status: **CLOSED / PHYSICALLY ACCEPTED**.

## D-H4 GNOME extension tree integrity — CLOSED

P0.3 / D-H4 is **implemented, repository-tested, and physically accepted** on the Fedora 44 / GNOME 50.5 workstation.

Implemented controls:

- `gnome/extensions-tree-lock.tsv` records the accepted deterministic SHA-256 for all 22 enabled user-extension trees;
- hashing covers relative paths, entry type, regular-file contents, regular-file modes, and symlink targets while intentionally excluding volatile mtime/UID/GID metadata;
- the repository validator requires complete, unique, version-matched, syntactically valid tree-lock entries for every enabled user extension;
- the full `scripts/verify.sh` performs fail-closed whole-tree comparison against the accepted lock;
- `scripts/install-extensions.sh` no longer treats a matching runtime version as sufficient: same-version tree drift is detected and triggers restoration from the existing pinned source lock;
- repository fixtures prove detection of changed file contents, added files, regular-file mode changes, symlink-target changes, and same-version tampering;
- integration-contract fixtures ensure future refactoring cannot silently detach tree integrity from restore or final verification.

Physical acceptance evidence on 2026-09-21:

```text
22/22 enabled user-extension trees: PASS
TREE_RC=0

controlled tamper test:
TAMPER_RC=3

tree restored to accepted SHA-256:
RESTORED_RC=0

full physical verifier:
PASS=247 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

The controlled tamper test used a temporary inert file in `user-theme@gnome-shell-extensions.gcampax.github.com`; the integrity verifier rejected the modified tree despite the runtime version remaining `79`, then accepted the tree again after the file was removed.

D-H4 status: **CLOSED / PHYSICALLY ACCEPTED**.

With D-H4 closed, all four High-severity findings from the 2026-09-21 audit remediation track are closed.
## DING System Monitor desktop-menu integration — PHYSICALLY ACCEPTED

The DING v97 desktop background context menu now contains a repository-managed `Monitor systemu` entry directly below `Otwórz w terminalu`.

Implementation and acceptance details:

- `patches/gnome-extensions/ding/desktopMenu-system-monitor.patch` adds the menu action and entry;
- `scripts/install-ding-system-monitor-menu.sh` applies the patch fail-closed only to the audited DING v97 runtime;
- `scripts/verify-ding-system-monitor-menu.sh` verifies the exact action block, menu entry, runtime version, and GNOME System Monitor desktop file;
- `install.sh` restores the customization as part of the normal workstation rebuild;
- `scripts/verify.sh` includes the customization in final physical acceptance;
- `gnome-system-monitor` is an explicit RPM dependency;
- `gnome/extensions-tree-lock.tsv` was updated only after visual confirmation and dedicated verification, so D-H4 continues to protect the customized final DING tree.

Physical acceptance on 2026-09-21:

```text
DING menu visual/function test: PASS
DING_MENU_RC=0
DING tree hash: a1e645bf8652d3256f1bc9aa6a24a359da1bf03cd6319d43d8d0e3b0743ba487
PASS=249 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

Status: **PHYSICALLY ACCEPTED / REPRODUCIBLE**.

## Application cleanup — PHYSICALLY ACCEPTED

A controlled workstation cleanup removed applications that were no longer part of the intended workflow:

- GNOME Snapshot (`snapshot`) was removed; it was not part of the repository RPM manifest;
- GNOME Boxes (`gnome-boxes`) was removed because VirtualBox remains the project virtualization platform;
- Fedora Media Writer (`mediawriter`) was removed;
- `htop` was removed while `btop` and GNOME System Monitor remain available.

Removing GNOME Boxes also allowed DNF to remove its now-unused libvirt/GlusterFS support dependencies. The repository RPM manifest was updated to remove only the three packages that had previously been explicit desired-state entries: `gnome-boxes`, `mediawriter`, and `htop`.

Final physical verification after cleanup:

```text
PASS=246 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

Status: **PHYSICALLY ACCEPTED / DESIRED STATE UPDATED**.

## Repository validation

Repository-only validation is automated through `scripts/check-static.sh`, which is used both locally and by GitHub Actions. It covers Bash syntax, error-level ShellCheck findings, Python syntax, gettext catalogs, JSON validation, desired-state inventory consistency, and current-tree high-confidence secret scanning.

GitHub Actions also runs a dedicated history-aware secret gate from a complete, non-shallow checkout. `scripts/scan-secrets.py --history` enumerates every reachable historical Git blob, checks secret-like historical filenames, and scans textual blob contents without printing matched secret values. A repository fixture proves that a synthetic token committed and later removed from the current tree is still detected by the history scan.

The live-system verifier is:

```bash
bash scripts/verify.sh
```

`FAIL` means required state is not satisfied. `WARN` means an actionable mismatch requires review. `SKIP` is used only for documented environment-specific exclusions.

## Current confidence

The repository has passed a clean-room functional restore test for Fedora 44 / GNOME 50.4 and a zero-warning, zero-failure physical-host verification on the Fedora 44 / GNOME 50.5 workstation after the accepted security, networking, extension, system-localization, GNOME Weather, localization, D-H4 integrity, DING System Monitor menu, and application-cleanup changes. The current complete physical-host aggregate is `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`. The accepted repository-trust layer verifies reviewed source URLs, local OpenPGP trust-anchor material, full fingerprints, package-signature enforcement, expected package signer identity, and COPR package scoping. The managed Helium and GNOME Tweaks fixes are physically accepted, the GNOME Tweaks `Hinting` override is visually confirmed, Bluetooth Battery Meter v49 is source-pinned with its validated EGO archive, and the private Weather location remains part of the verified local desired state without publishing its identifying data.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, Tailscale node identity, private signing keys, and other private state must be restored separately.

## 2026-09-24 Tailscale firewalld isolation — IMPLEMENTED / PHYSICALLY ACCEPTED

Issue #11 identified a concrete gap in the broader firewalld fallback path.

Observed before remediation:

```text
tailscale0 -> no explicit firewalld zone
default fallback -> FedoraWorkstation
FedoraWorkstation -> TCP/22 + TCP/UDP 1025-65535 allowed
remote Tailnet scan:
22/tcp      closed
1716/tcp    open
27036/tcp   open
```

The local listeners behind the two confirmed open ports were GSConnect/KDE Connect on TCP/1716 and Steam on TCP/27036.

A bounded runtime A/B test moved `tailscale0` into a rejecting zone without changing the trusted Wi-Fi policy. Fedora retained outbound Tailscale connectivity to the Windows peer, while the same remote scan changed all three tested ports to `filtered`.

The accepted design is now a dedicated exact-state zone:

```text
zone: workstation-tailscale
interface: tailscale0
target: DROP
services: none
ports: none
protocols: none
sources: none
forward: no
masquerade: no
rich rules: none
```

The configuration survived `firewall-cmd --reload` and a physical reboot. After reboot, `tailscale0` remained in `workstation-tailscale`, the trusted Wi-Fi interface remained in `workstation-kdeconnect`, outbound `tailscale ping` still passed, and TCP/22, TCP/1716 and TCP/27036 remained `filtered` from the Windows Tailnet peer.

Repository work makes this state reproducible through `network/tailscale-firewall-zone.sh`, installer integration, static fixtures and explicit security-posture verification. After correcting the portable runtime target check, the dedicated physical security verifier completed at `PASS=62 WARN=0 FAIL=0 SKIP=0`, and the complete workstation verifier completed at `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`. The `workstation-tailscale` policy is therefore part of the accepted 2026-09-24 physical baseline.

## Planned desktop-environment expansion

Public Issue #12 now tracks a future **GNOME + KDE Plasma** coexistence design. This is a planned feature and does **not** change the currently accepted Fedora 44 / GNOME 50.5 baseline.

The intended first phase keeps GNOME as the canonical production desktop and adds KDE Plasma as an optional alternate session without replacing GNOME or changing the display manager at the same time. Promotion into the supported desired state requires explicit validation of session switching and rollback, XDG portals, MIME/default applications, keyring/KWallet behavior, autostart interactions, Wayland behavior, networking/Tailscale, audio, Bluetooth, removable storage, reproducible KDE configuration capture/restore, and the full repository verifier.

## Remaining work

The High-severity audit-remediation track is complete. Remaining work is medium/lower-risk hardening, planned desktop-environment work, and routine lifecycle maintenance:
- complete the planned GNOME + KDE Plasma coexistence validation tracked by Issue #12 before treating KDE as part of the supported desired state;
- introduce LUKS during a future controlled reinstall/restore if full-disk encryption is desired; in-place conversion remains intentionally deferred;
- keep package and GNOME extension pins current as Fedora evolves;
- repeat the clean-room restore test after material restore-path or supported-baseline changes;
- keep private machine-specific configuration and signing material separate from the public repository;
- rerun physical-host verification after material desired-state changes, especially kernel/NVIDIA updates;
- re-audit version-pinned localization whenever an extension or application version changes;
- keep VSCodium localization explicitly deferred until it is intentionally brought into scope;
- follow `docs/UPGRADE.md` for future Fedora/GNOME major-version changes, including target-release repository review, clean-room validation, physical acceptance, and post-upgrade DR refresh.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; the detailed total-failure operational sequence is documented in `docs/DISASTER-RECOVERY-RUNBOOK.md`. These complement rather than replace the repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when required packages, repositories, GNOME extensions, schemas, curated GNOME state, localization artifacts, required services, selected security controls, Secure Boot/NVIDIA signing state, and network/firewalld policy all match the documented desired state, while private data remains outside the public repository.

`scripts/verify.sh` must report zero `WARN` and zero `FAIL` on the validated physical target.

**Last complete accepted physical aggregate: `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`.**
