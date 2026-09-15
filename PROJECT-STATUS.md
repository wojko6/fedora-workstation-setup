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

The eight `SKIP` results are intentional environment-specific exclusions rather than unresolved warnings:

- VirtualBox host packages are not required inside the VirtualBox guest.
- NVIDIA host drivers are not required inside the test VM.
- Physical Wi-Fi power-management validation is not applicable to the VM.
- The DING source `.po` file is not a runtime requirement when the compiled `.mo` matches.
- Private ASUS launcher configuration and its generated launcher are intentionally absent from a public clean clone.

After post-restore maintenance, the current desired state was also verified on the physical Fedora workstation:

```text
PASS=159 WARN=0 FAIL=0 SKIP=0
```

This physical-host validation includes Brave Origin, the Fedora-packaged Tailscale client, and checks confirming that `tailscaled` is enabled and active. Authentication and tailnet identity remain private state and are intentionally not validated or stored by this repository.

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

## Current confidence

The repository has passed a clean-room functional restore test for the tested Fedora 44 / GNOME 50.4 baseline and a zero-warning, zero-failure desired-state verification on the physical workstation. Package installation, repositories, Flatpaks, pinned GNOME extensions, extension schemas, curated GNOME settings, desktop launcher restoration, the DING translation patch, Tailscale package/service state, and verification logic have been exercised across these validation stages.

This does not make the repository a full disk backup. Personal files, credentials, SSH private keys, Wi-Fi secrets, browser profiles, password-manager data, VPN authentication state, Tailscale node identity, and other private state remain intentionally outside Git and must be restored separately.

## Remaining work

The remaining work is maintenance rather than a known restore blocker:

- keep package and GNOME extension pins current as Fedora evolves;
- periodically repeat the clean-room restore test after major Fedora/GNOME changes;
- keep private machine-specific configuration separate from the public repository;
- optionally refine minor visual ordering differences in the GNOME top panel;
- periodically re-run physical-host verification after material desired-state changes.

The separate disaster-recovery layer is documented in `docs/DISASTER-RECOVERY.md`; it complements rather than replaces this repository-based rebuild path.

## Acceptance criteria

The tested baseline is considered accepted when:

- required packages and repositories are restored or explicitly classified as environment-specific;
- required GNOME extensions are installed and `ACTIVE`;
- extension schemas are compiled where required;
- curated GNOME desired-state checks match;
- runtime translation artifacts match;
- required system services such as `tailscaled` are present and operational where applicable;
- private data is not required from the public repository;
- `scripts/verify.sh` reports zero `WARN` and zero `FAIL` on the validated target, with only documented environment-specific `SKIP` results where applicable.

**Current result: ACCEPTED.**
