# Restore procedure

## Objective

Rebuild the workstation from a clean Fedora installation using reviewed configuration rather than restoring an opaque full-system snapshot.

## Safety model

The repository must not contain passwords, Wi-Fi PSKs, private SSH keys, authentication tokens, password-manager data, browser profiles, raw shell history, precise/private location data, or unreviewed full dconf dumps.

## High-level procedure

1. Install Fedora and fully update the base system.
2. Clone this repository.
3. Review the manifests and machine-specific variables.
4. Run `./install.sh`.
5. Restore private user data from a separate encrypted backup.
6. Reboot or sign out/in when GNOME changes require it.
7. Run `scripts/verify.sh` and compare the result with the documented baseline.

## Current baseline checks

Expected current physical-workstation characteristics include Fedora 44, GNOME 50.5, Wayland, and Wi-Fi power saving disabled for the selected NetworkManager Wi-Fi profile.

## Acceptance and verification

The Fedora 44 / GNOME 50.4 restore path has passed historical clean-room validation. The current accepted Fedora 44 / GNOME 50.5 physical-host aggregate is `PASS=231 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`. `install.sh` restores the reviewed desired state, including the centralized localization pipeline and optional private GNOME Weather custom locations. The public repository stores only an anonymized example; real Weather names and coordinates must be restored separately as the gitignored `gnome/weather-locations.local.tsv`. The Weather stage runs after the curated GNOME dconf restore and uses libgweather serialization rather than copying opaque location state. A successful installer exit is not the final acceptance signal: after the required GNOME session restart, run `bash scripts/verify.sh` and require zero `WARN` and zero `FAIL` for the validated physical target.

Private user data, credentials, browser profiles, password-manager data, Tailscale node identity, and other secrets remain outside this repository and must be restored separately.
