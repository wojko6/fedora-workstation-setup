# Restore procedure

## Objective

Rebuild the workstation from a clean Fedora installation using reviewed configuration rather than restoring an opaque full-system snapshot.

## Safety model

The repository must not contain passwords, Wi-Fi PSKs, private SSH keys, authentication tokens, password-manager data, browser profiles, raw shell history, or unreviewed full dconf dumps.

## High-level procedure

1. Install Fedora and fully update the base system.
2. Clone this repository.
3. Review the manifests and machine-specific variables.
4. Run `./install.sh` once the repository status marks all required stages as ready.
5. Restore private user data from a separate encrypted backup.
6. Reboot or sign out/in when GNOME changes require it.
7. Run `scripts/verify.sh` and compare the result with the documented baseline.

## Current baseline checks

Expected source workstation characteristics include Fedora 44, GNOME 50.4, Wayland, and Wi-Fi power saving disabled for the selected NetworkManager Wi-Fi profile.

## Important

This repository is under construction. A successful script exit does not yet mean the workstation has been completely reproduced. The README tracks the current implementation status.
