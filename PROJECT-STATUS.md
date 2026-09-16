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

After post-restore maintenance, the 2026-09-16 workstation security validation, Secure Boot enablement, and the latest reproducible workstation configuration updates, the current desired state was verified on the physical Fedora workstation:

```text
PASS=175 WARN=0 FAIL=0 SKIP=0
```

The physical-host validation includes Brave Origin, Tailscale package/service state, Wi-Fi firewall-zone policy, disabled LLMNR, disabled GNOME/GVfs WS-Discovery, workstation kernel hardening, Secure Boot, signed NVIDIA kernel-module verification, and reproducible DDC/CI support for external-monitor brightness control. Authentication, network identities, credentials, private signing material, and other private state remain intentionally outside Git.

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

The latest physical verifier run, after the current desired-state updates including DDC/CI external-monitor brightness support and order-insensitive GNOME favorite-app auditing, returned:

```text
PASS=175 WARN=0 FAIL=0 SKIP=0
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

## Current confidence

The repository has passed a clean-room functional restore test for the tested Fedora 44 / GNOME 50.4 baseline and a zero-warning, zero-failure desired-state verification on the physical workstation after security hardening, a material NVIDIA/graphics-stack update, Secure Boot activation, and the latest workstation desired-state updates. Package installation, repositories, Flatpaks, pinned GNOME extensions, extension schemas, curated GNOME settings, desktop launcher restoration, the DING translation patch, network/security controls, Tailscale package/service state, Secure Boot state, NVIDIA module signing, DDC/CI support, and verification logic have been exercised across these validation stages.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, VPN authentication state, Tailscale node identity, private signing keys, and other private state remain intentionally outside Git and must be restored separately.

## Remaining work

The remaining work is maintenance plus one explicitly deferred security decision:

- introduce LUKS during a future controlled reinstall/restore if full-disk encryption is desired;
- keep package and GNOME extension pins current as Fedora evolves;
- periodically repeat the clean-room restore test after major Fedora/GNOME changes;
- keep private machine-specific configuration and signing material separate from the public repository;
- periodically re-run physical-host verification after material desired-state changes, especially kernel/NVIDIA updates.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; it complements rather than replaces this repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when:

- required packages and repositories are restored or explicitly classified as environment-specific;
- required GNOME extensions are installed and `ACTIVE`;
- extension schemas are compiled where required;
- curated GNOME desired-state checks match;
- runtime translation artifacts match;
- required system services such as `tailscaled` are present and operational where applicable;
- selected workstation security controls are reproducible and verified;
- Secure Boot and NVIDIA module signing match the accepted physical-host state;
- private data is not required from the public repository;
- `scripts/verify.sh` reports zero `WARN` and zero `FAIL` on the validated target, with only documented environment-specific `SKIP` results where applicable.

**Current result: ACCEPTED.**
