# Project Status

**Status:** Clean-room restore validated; physical workstation desired state verified  
**Baseline:** Fedora 44 · GNOME Shell 50.4 · Wayland  
**Validation environments:** Oracle VirtualBox clean-room VM and physical workstation

## Objective

This repository defines a reproducible desired state for a Fedora workstation. The goal is to rebuild the workstation after a clean Fedora installation without restoring an opaque system image and without storing private user data in Git.

## Validation results

The restore workflow was exercised against a clean Fedora 44 virtual machine and then verified after the guest was fully updated to GNOME Shell 50.4.

Clean-room VM result:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

All required GNOME extensions were installed and reported `ACTIVE` at runtime. The curated GNOME desired-state audit completed with 78 matching checks. The custom DING Polish runtime translation matched the repository source after compilation.

The eight `SKIP` results are intentional environment-specific exclusions rather than unresolved warnings.

After post-restore maintenance, the 2026-09-16 workstation security validation, Secure Boot enablement, the 2026-09-17 GNOME extension compatibility refresh, and completion of the accepted Polish localization overlays, the current desired state was verified on the physical Fedora workstation:

```text
PASS=219 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

The physical-host validation includes Brave Origin, Tailscale package/service state, Wi-Fi firewall-zone policy, disabled LLMNR, disabled GNOME/GVfs WS-Discovery, workstation kernel hardening, Secure Boot, signed NVIDIA kernel-module verification, reproducible DDC/CI support for external-monitor brightness control, the accepted GNOME extension runtime state, and dedicated verification of the GSConnect and Tiling Shell Polish localization completions. Authentication, network identities, credentials, private signing material, and other private state remain intentionally outside Git.

## GNOME extension compatibility refresh — 2026-09-17

A controlled extension refresh was audited on the physical Fedora 44 / GNOME 50.4 workstation before the candidate set was promoted into desired state.

Seven third-party extensions passed the runtime/compatibility checks and were accepted: ArcMenu, Bluetooth Battery Meter, Caffeine, Freon, GSConnect, Tiling Shell, and User Themes. Media Controls was rejected and removed because the installed release reported `OUT OF DATE` and did not declare GNOME 50 compatibility. Dash2Dock Animated declared GNOME 50 compatibility but was removed because Dhruva is the canonical dock and running both produced duplicate docks.

GSConnect validation included the shell extension runtime, user D-Bus registration and introspection, and the `kdeconnect` service in the active Wi-Fi firewalld `public` zone. Phone-side Tailscale split-tunneling policy remains intentionally outside Fedora desired state.

The refresh also corrected reproducibility details discovered by physical testing: extension inventory paths are normalized to `~/.local/...`, inventory rows are deterministic and UUID-deduplicated, and legitimate live-state changes to the Mutter overlay key, Just Perfection clock position, and Dhruva dock contents were reviewed before being accepted.

The final extension inventory was regenerated only after the rejected extensions were uninstalled. Full details are recorded in `docs/gnome-extension-audit-2026-09-17.md`.

## Security validation — 2026-09-16

A focused physical-workstation security review was completed without weakening the reproducible restore model.

Validated and applied controls:

- systemd-resolved LLMNR is disabled globally; TCP/5355 was externally tested before and after the change;
- `kernel.kptr_restrict=1` is persistent and survived reboot/regression testing;
- GNOME/GVfs WS-Discovery is disabled because SMB/WSD discovery is not required, while Avahi/mDNS is intentionally retained for local printer discovery;
- the physical Wi-Fi NetworkManager profile is persistently assigned to firewalld's `public` zone instead of relying on the permissive FedoraWorkstation zone;
- SSH server remains disabled/inactive and the system reports no failed services;
- SELinux remains enforcing;
- package updates are detected/downloaded and surfaced to the user, while installation remains a controlled operation rather than an unattended full-system upgrade;
- Secure Boot is enabled and verified on the physical workstation;
- the local akmods signing certificate is enrolled through MOK, and the NVIDIA kernel module is signed with SHA-256 and loads successfully under Secure Boot;
- kernel lockdown reports `integrity` as the active mode under the validated Secure Boot configuration.

The update policy was exercised with a material graphics-stack update. NVIDIA/akmods was upgraded from 610.57.04 to 615.71.09. The kmod for kernel `7.2.5-200.fc44.x86_64` was built successfully, its module was signed, the machine rebooted successfully, and the RTX 3060 was operational on driver 615.71.09 afterward. Secure Boot was subsequently enabled after MOK enrollment; NVIDIA 615.71.09 remained operational and the system reported zero failed services.

The latest physical verifier run, after extension cleanup and the completed localization work, returned:

```text
PASS=219 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

### Deferred security item

The current Fedora system partition is Btrfs without a LUKS layer. Full-disk encryption is therefore not claimed by this project. A future controlled reinstall/restore is the preferred point to introduce LUKS rather than attempting risky in-place conversion of the current workstation.

## Issues discovered by clean-room and post-restore testing

Testing on a pristine system and subsequent physical-host verification exposed several problems that were not visible on the already-configured workstation:

1. The previous NordVPN repository bootstrap path was obsolete on a fresh Fedora/DNF5 installation. The restore now uses the current NordVPN Linux installer.
2. Fedora's `ffmpeg-free` conflicted with the RPM Fusion `ffmpeg` package. The installer now performs an explicit, controlled replacement.
3. GNOME Extensions archive URLs were constructed incorrectly by replacing dots in UUIDs. EGO archive naming now removes `@` while preserving dots.
4. Dhruva's EGO archive version differs from its internal extension metadata version. Verification now handles that pin correctly.
5. User GNOME extension archives contained GSettings schema XML files but no compiled `gschemas.compiled`. The installer now compiles schemas and treats compilation failure as an installation failure.
6. The verifier previously checked extension presence but could miss extensions in runtime `ERROR` state. Required extensions must now report `ACTIVE`.
7. The GNOME Amber wallpaper was present on Fedora but its desired URI was not captured. The curated dconf state now restores the correct light/dark wallpaper URIs.
8. VM-only differences previously appeared as warnings. Verification now distinguishes intentional `SKIP` conditions from actionable `WARN` and `FAIL` results.
9. Tailscale was absent from the original restore manifest. It is now part of the RPM desired state and its systemd service state is verified without automating authentication.
10. The application baseline was corrected from the legacy Brave package expectation to Brave Origin, matching the current workstation desired state.
11. External-repository verification was aligned with the actual NordVPN repository identifier used on the workstation.
12. The default physical Wi-Fi/firewalld relationship was broader than required. The desired state now assigns the Wi-Fi profile to the `public` zone and verifies both saved and active zone state.
13. LLMNR and GNOME/GVfs WS-Discovery exposed discovery surfaces that were unnecessary for this workstation. Both are now disabled reproducibly while required mDNS remains available.
14. Kernel pointer visibility was more permissive than the selected workstation policy. `kernel.kptr_restrict=1` is now persistent and verified.
15. Secure Boot had been disabled despite the NVIDIA akmods module already being locally signed. The signing certificate was enrolled through MOK, Secure Boot was enabled, and the NVIDIA path was validated before the state was accepted.
16. External-monitor brightness control through DDC/CI required `ddcutil` plus the packaged Fedora udev access rules. The restore now installs `ddcutil`, initializes the udev access path, and tracks the GNOME brightness extension in desired state.
17. GNOME favorite-app ordering was producing non-actionable desired-state drift. The audit now requires the same favorite applications while intentionally allowing their icon order to vary.
18. Dhruva maintains its own dock-order and application-folder state independently of GNOME `favorite-apps`. A stale Dhruva order could therefore survive even when the GNOME favorites matched the repository. The restore applies a sanitized, deterministic Dhruva dock state after GNOME restoration, and the verifier checks both the dock order and application-folder definitions.
19. A broad extension refresh can introduce components that are installed but not suitable for the accepted baseline. The runtime audit now separates candidate testing from desired-state promotion; incompatible or conflicting extensions remain outside `enabled-extensions.txt` and are removed before the accepted inventory is regenerated.
20. Extension inventory generation initially exposed an absolute home path. The generator now normalizes user locations to `~`, resolves duplicate UUIDs deterministically, and emits stable sorted output.
21. GSConnect v72 shipped a valid Polish catalog but omitted the metadata `gettext-domain` required by GNOME Shell for its Quick Settings strings. The repository now applies the domain fix reproducibly and verifies both the merged catalog and metadata state.
22. Tiling Shell v76 / 17.3 shipped 15 untranslated Polish strings. The repository now carries a minimal completion overlay pinned to that tested version and verifies that the merged catalog has zero untranslated and zero fuzzy entries.

## Reproducible Polish GNOME localization

The repository also carries reproducible Polish localization support for selected GNOME Shell extensions whose upstream packages either lack complete Polish translations or contain user-visible strings that are not exposed through an existing Polish gettext catalog.

The Dhruva GNOME extension is the most extensive localization case. The accepted implementation includes:

- a Polish gettext catalog containing 393 translated messages;
- a 20-file source patch set that introduces gettext support across preferences and runtime UI;
- Polish localization of application-grid, context-menu, trash, folder, dock, monitor, layout, behavior, appearance, module, and related user-visible strings;
- a generated Polish emoji metadata database based on Fedora CLDR annotations, covering all 1907 emoji used by the tested Dhruva source;
- search support that retains the original English emoji terms while adding Polish names and keywords;
- an idempotent localization installer that validates prerequisites, patch applicability, gettext compilation, generated emoji data, and the final installed state;
- verifier coverage for the installed gettext catalog, Dhruva gettext integration, generated emoji database, and expected patch-set structure.

Dhruva's accepted desired state also includes a sanitized reproducible dock layout. The implementation was tested by first confirming that the verifier detected deliberate live-state drift, then applying the repository state and confirming successful restoration. After a GNOME sign-out/sign-in, the restored dock was also checked visually.

Before acceptance, all 20 Dhruva patches were applied against a clean upstream source tree with `--fuzz=0`; all 20 applied successfully without offset or fuzz. Dhruva v17 remained compatible with the repository-managed Polish localization during the 2026-09-17 refresh.

GSConnect v72 was audited separately. Its upstream Polish catalog had 11 untranslated entries and no fuzzy entries. The repository carries only those missing translations as a merge overlay. Runtime testing also identified the missing Shell gettext-domain metadata; after the domain fix, the Quick Settings strings were confirmed in Polish on the physical host.

Tiling Shell v76 / 17.3 was also audited against the exact installed version. Its upstream Polish catalog had 15 untranslated entries and no fuzzy entries. A minimal completion overlay was installed and verified, and the affected preferences were visually checked on the physical host. Both GSConnect and Tiling Shell dedicated verifiers are integrated into the main repository verifier.

The localization is maintained as source material rather than as opaque modified extension archives. This keeps the customization reviewable and reproducible while allowing the original extensions to remain separately identifiable.

## Third-party extension attribution

The GNOME Shell extensions integrated by this repository remain third-party software authored and licensed by their respective upstream projects. This repository does not claim authorship of those extensions. Its work is the reproducible integration layer: package/version tracking, installation and restore logic, configuration, compatibility/runtime audits, conflict handling, selected localization changes, security integration, and verification/documentation.

## Current confidence

The repository has passed a clean-room functional restore test for the tested Fedora 44 / GNOME 50.4 baseline and a zero-warning, zero-failure desired-state verification on the physical workstation after security hardening, a material NVIDIA/graphics-stack update, Secure Boot activation, DDC/CI integration, the GNOME extension compatibility refresh, and the completed GSConnect/Tiling Shell localization validation. Package installation, repositories, Flatpaks, pinned GNOME extensions, extension schemas, curated GNOME settings, desktop launcher restoration, reproducible Polish GNOME extension localizations including Dhruva, GSConnect, and Tiling Shell, network/security controls, Tailscale package/service state, Secure Boot state, NVIDIA module signing, DDC/CI support, and verification logic have been exercised across these validation stages.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, VPN authentication state, Tailscale node identity, private signing keys, and other private state remain intentionally outside Git and must be restored separately.

## Remaining work

The remaining work is maintenance plus one explicitly deferred security decision:

- introduce LUKS during a future controlled reinstall/restore if full-disk encryption is desired;
- keep package and GNOME extension pins current as Fedora evolves;
- periodically repeat the clean-room restore test after major Fedora/GNOME changes;
- keep private machine-specific configuration and signing material separate from the public repository;
- periodically re-run physical-host verification after material desired-state changes, especially kernel/NVIDIA updates;
- periodically audit upstream Polish localization coverage for accepted third-party extensions and carry repository-managed translations only where there is a demonstrated gap.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; it complements rather than replaces this repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when:

- required packages and repositories are restored or explicitly classified as environment-specific;
- required GNOME extensions are installed and `ACTIVE`;
- extension schemas are compiled where required;
- curated GNOME desired-state checks match;
- runtime translation artifacts and repository-managed localization sources match;
- required system services such as `tailscaled` are present and operational where applicable;
- selected workstation security controls are reproducible and verified;
- Secure Boot and NVIDIA module signing match the accepted physical-host state;
- private data is not required from the public repository;
- `scripts/verify.sh` reports zero `WARN` and zero `FAIL` on the validated target, with only documented environment-specific `SKIP` results where applicable.

**Current result: ACCEPTED (`PASS=219 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`).**
