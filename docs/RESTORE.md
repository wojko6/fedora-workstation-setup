# Restore procedure

## Objective

Rebuild the workstation from a clean Fedora installation using reviewed configuration rather than restoring an opaque full-system snapshot.

## Safety model

The repository must not contain passwords, Wi-Fi PSKs, private SSH keys, authentication tokens, password-manager data, browser profiles, raw shell history, precise/private location data, or unreviewed full dconf dumps.

## High-level procedure

1. Install Fedora and fully update the base system.
2. Clone this repository.
3. Review the manifests and machine-specific variables.
4. On a physical host, review the intended trusted Wi-Fi connection with `nmcli -f NAME,UUID,TYPE connection show`.
5. Run `TRUSTED_WIFI_UUID='<reviewed-uuid>' bash install.sh`. Optionally also set `TRUSTED_WIFI_PROFILE='<reviewed-profile-name>'`.
6. Restore private user data from a separate encrypted backup.
7. Reboot or sign out/in when GNOME changes require it.
8. Run `scripts/verify.sh` and compare the result with the documented baseline.

## Current baseline checks

Expected current physical-workstation characteristics include Fedora 44, GNOME 50.5, Wayland, and Wi-Fi power saving disabled for the selected NetworkManager Wi-Fi profile.

The trusted Wi-Fi identity is local recovery input, not public desired-state data. On a physical host the restore preflight requires a reviewed `TRUSTED_WIFI_UUID` before any setup stages run. The firewall stage refuses an active/default-route Wi-Fi profile with a different UUID and manages `workstation-kdeconnect` as exact state with only `dhcpv6-client`, `mdns`, and `kdeconnect`; SSH and forwarding are not part of the accepted zone policy.

A separate restore stage creates `workstation-tailscale` as exact state and permanently binds `tailscale0` to it. The zone uses target `DROP` and carries no allowed services, explicit ports, protocols, sources, forwarding, masquerade, ICMP inversion, or rich rules. Tailscale authentication/node identity remains private and is not automated; the permanent firewalld binding can be prepared before that identity is restored.

## Acceptance and verification

The Fedora 44 / GNOME 50.4 restore path has passed historical clean-room validation. The current accepted Fedora 44 / GNOME 50.5 physical-host aggregate is `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0` after the later application cleanup, OpenSSH server removal, Helium desired-state promotion, VPCS COPR restriction, Firefox exclusion, and deterministic MOK signer verification fix. `install.sh` restores the reviewed desired state, including the centralized localization pipeline, the version-pinned DING v97 `Monitor systemu` desktop-menu customization, and optional private GNOME Weather custom locations. The public repository stores only an anonymized example; real Weather names and coordinates must be restored separately as the gitignored `gnome/weather-locations.local.tsv`. The Weather stage runs after the curated GNOME dconf restore and uses libgweather serialization rather than copying opaque location state. A successful installer exit is not the final acceptance signal: after the required GNOME session restart, run `bash scripts/verify.sh` and require zero `WARN` and zero `FAIL` for the validated physical target. Enabled user-extension trees must also match `gnome/extensions-tree-lock.tsv`; a matching runtime version alone is not accepted.

Private user data, credentials, browser profiles, password-manager data, Tailscale node identity, and other secrets remain outside this repository and must be restored separately.


## Total-failure recovery

This document covers the preferred clean rebuild path. If the system disk is lost, the boot chain is destroyed, or the previous filesystem state must be reconstructed from the private offline backup, follow [DISASTER-RECOVERY-RUNBOOK.md](DISASTER-RECOVERY-RUNBOOK.md) instead.

The runbook begins from Fedora Live media, requires recovery-set integrity verification before restore, separates clean rebuild from filesystem-level recovery, and ends with the same repository verifier acceptance model.
