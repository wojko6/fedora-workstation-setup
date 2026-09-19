# Clean-room Restore Validation Report

## Scope

This report documents the clean Fedora restore test performed for `fedora-workstation-setup`. The test was designed to expose assumptions that can remain hidden when restore scripts are developed only on an already-configured workstation.

## Test environment

- Fedora 44 Workstation
- GNOME Shell 50.4 after system update
- Wayland session
- Oracle VirtualBox guest
- 4 vCPUs
- 4 GiB RAM
- 50 GiB virtual disk
- clean Fedora installation before repository restore

The physical source workstation uses the same Fedora 44 / GNOME 50.4 / Wayland baseline. Hardware-specific checks such as the physical Realtek Wi-Fi adapter and NVIDIA driver stack are intentionally excluded inside the VM.

## Method

The repository was cloned into a freshly installed Fedora VM. Restore stages were executed and failures were investigated rather than bypassed. After fixes were committed, the VM was updated and rebooted, GNOME extension runtime state was rechecked, and `scripts/verify.sh` was run as the final acceptance test.

## Defects found and corrected

### NordVPN bootstrap

The previous repository bootstrap used an obsolete NordVPN RPM path that failed on the clean Fedora/DNF5 environment. The restore flow was changed to the current NordVPN Linux installer path.

### Multimedia package replacement

The clean Fedora installation contained `ffmpeg-free`, while the desired RPM Fusion state requires `ffmpeg`. A controlled `dnf install --allowerasing ffmpeg` replacement is now performed only when the manifest requests `ffmpeg` and `ffmpeg-free` is installed.

### GNOME Extensions archive naming

The original EGO URL construction replaced both `@` and dots in extension UUIDs, causing HTTP 404 responses. The corrected naming removes `@` and preserves dots.

### Extension GSettings schemas

Several user extensions extracted successfully but entered GNOME Shell runtime `ERROR` state. Investigation showed that their `schemas/*.gschema.xml` files existed while `schemas/gschemas.compiled` did not. The installer now runs `glib-compile-schemas` for user extensions that ship schema XML and fails if compilation does not produce the runtime schema database.

### Runtime verification

Checking only whether an extension is installed is insufficient. The verifier now requires each desired extension to report `ACTIVE` and also checks `gschemas.compiled` when schema XML exists.

### Dhruva source pinning

Follow-up validation established that Dhruva runtime version 17 / 2.0 is not the EGO v16 package. The reproducible source for the accepted workstation state is upstream GitHub commit `f8121f68fcef48c0324e8cd87fd30bf9a2131962`. The restore path therefore uses an explicit source lock instead of mapping runtime version 17 to the older EGO v16 archive.

### GNOME wallpaper

The desired workstation uses the GNOME Amber light/dark wallpaper files already supplied by Fedora. The restore state now explicitly sets the light and dark wallpaper URIs instead of relying on the Fedora default background.

### Environment-aware verification

The final verifier detects virtualization with `systemd-detect-virt`. Host-only VirtualBox/NVIDIA packages and physical Wi-Fi checks are reported as `SKIP` inside the VM. Optional private ASUS launcher state is also distinguished from a restore warning. This keeps genuine warnings visible without penalizing the clean-room environment for intentionally inapplicable checks.

## Final result

```text
Fedora release 44 (Forty Four)
GNOME Shell 50.4
Session: wayland
Virtualization: oracle

GNOME desired state matches (78 checks)

PASS=147 WARN=0 FAIL=0 SKIP=8
```

All 19 required GNOME extensions reported `ACTIVE` in the final runtime test. Extensions that ship local GSettings schemas had compiled schema databases present. The DING compiled Polish translation matched the repository translation source.

## Interpretation of SKIP results

`SKIP` is not a suppressed failure. It indicates that a check is deliberately not applicable to the current validation environment. In the final VM run the eight skips represented four host-only VirtualBox/NVIDIA packages, the physical Wi-Fi check, the non-runtime DING source `.po` comparison, and two private ASUS launcher checks.

On a physical workstation, relevant hardware checks remain actionable and are not converted to VM skips.

## Security and privacy boundary

The public repository represents desired configuration, not user secrets. The clean-room test does not require Wi-Fi credentials, private SSH keys, browser profiles, password-manager vaults, VPN authentication tokens, shell history, or actual private ASUS router connection details from Git.

Private user data must be restored through a separate protected backup process.

## Conclusion

The Fedora 44 / GNOME 50.4 clean-room validation is successful. The test did more than demonstrate that scripts exit successfully: it exposed installation, package-resolution, GNOME runtime, schema-compilation, visual-state, version-verification, and environment-classification defects, which were corrected and retested.

For the tested baseline, the repository is accepted as a reproducible workstation configuration and restore mechanism. Future Fedora or GNOME upgrades should trigger another clean-room validation cycle before a new baseline is declared accepted.
