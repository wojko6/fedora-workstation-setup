# Scripts index

The scripts directory contains the operational entrypoints used to build, restore, audit, and verify the Fedora workstation desired state.

## Primary entrypoints

- `check-static.sh` — repository-only validation used locally and by GitHub Actions.
- `scan-secrets.py` — high-confidence secret scanner for the current tracked tree; `--history` scans every reachable historical Git blob and fails on shallow clones so deleted credentials cannot evade the CI gate.
- `verify.sh` — full live-system verifier after restore and GNOME session restart.
- `restore-gnome.sh` — restore the reviewed GNOME dconf state.
- `audit-extension-runtime.sh` — extension-focused runtime audit.

## Install and setup stages

- `setup-repositories.sh`
- `install-packages.sh`
- `install-flatpaks.sh`
- `install-extensions.sh`
- `setup-ddcutil.sh`
- `install-localizations.sh`
- `install-ding-system-monitor-menu.sh` — applies the audited DING v97 desktop-menu patch that adds `Monitor systemu` and fails closed on version/source drift.
- `install-launchers.sh`
- `install-weather-locations.sh` — restores reviewed custom GNOME Weather locations in the user session.
- `install-dhruva-config.sh`
- `manage-weather-locations.py` — libgweather-backed installer/verifier for reviewed custom GNOME Weather locations.
- `../network/firewall-zone.sh` — exact-state trusted-Wi-Fi firewalld policy for `workstation-kdeconnect`.
- `../network/tailscale-firewall-zone.sh` — exact-state `workstation-tailscale` policy that binds `tailscale0` to a DROP-by-default zone without explicit inbound services or ports.

The top-level `install.sh` orchestrates these stages. Individual stages should remain safe to inspect and, where practical, safe to rerun.

## Localization

`install-localizations.sh` is the single localization pipeline. It manages **25 localization targets/operations**: four generic gettext targets, 15 specialized GNOME-extension stages, and six application/system stages (Papers/Nautilus, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks).

Dedicated `verify-*-localization.sh` scripts validate exact-version, completion-overlay, and system-localization targets and are wired into `verify.sh`.

The Bluetooth Battery Meter helper pair installs and verifies the v46/v49 BudsLink Companion completion overlay:

- `install-bluetooth-battery-meter-localization.sh`
- `verify-bluetooth-battery-meter-localization.sh`
- `install-clipboard-indicator-localization.sh` / `verify-clipboard-indicator-localization.sh` — Clipboard Indicator v71 63-entry Polish completion over the audited upstream catalog.
- `install-blur-my-shell-localization.sh` / `verify-blur-my-shell-localization.sh` — Blur my Shell v72 61-entry Polish completion plus two pipeline UI source patches over the audited physical EGO build.

- `install-extension-manager-localization.sh` / `verify-extension-manager-localization.sh` — Extension Manager 0.6.5 Flatpak Locale one-entry contextual completion (`None` → `Brak`) pinned to the audited Locale commit and pristine catalog hash.
- `install-helium-localization.sh` / `verify-helium-localization.sh` — Helium 0.17.2.1 36-entry Polish DataPack v5 completion plus DNF5 post-transaction persistence.
- `helium_datapack.py` — dependency-free Chromium DataPack v5 parser/writer used to apply and verify Helium locale overlays without replacing unrelated producer resources.
- `helium-localization-post-transaction.sh` — root helper installed for the DNF5 `post_transaction` hook; it keeps versioned pristine producer backups and patches only entries that still match their audited English source.
- `install-gnome-tweaks-localization.sh` / `verify-gnome-tweaks-localization.sh` — GNOME Tweaks 49.0 exact-package localization bridge for generated GSettings enum labels, with pristine source/catalog backups and byte-for-byte reconstruction.

System localization helpers:
- `install-papers-localization.sh` / `verify-papers-localization.sh` — Papers 49.8 / Nautilus Polish completion for confirmed document-properties, annotations-sidebar, and empty-start-page gaps.
- `install-plymouth-localization.sh` / `verify-plymouth-localization.sh` — Fedora 44 Plymouth offline-update Polish locale persistence through dracut.
- `install-ptyxis-localization.sh` / `verify-ptyxis-localization.sh` — Ptyxis 50.1-2.fc44 Polish main-domain completion for the audited in-application UI plus exact-fingerprint localization of the GNOME Shell `.desktop` actions `New Window`, `New Tab`, and `Preferences`.

## GNOME Keyring i18n

- `build-gnome-keyring-i18n-backport.sh` — Fedora 44 / GNOME Keyring gettext backport build pinned to exact SRPM NVR `gnome-keyring-50.0-1.fc44`, SHA-256, valid RPM signature, and the reviewed full Fedora 44 signer fingerprint; `--verify-only` performs the producer-provenance gate without building.
- `verify-gnome-keyring-i18n.sh` — runtime/package/catalog verification.

## Generators and helpers

- `apply-space-bar-localization.py`
- `gsconnect_runcommand_names.py` — safely localizes the five audited GSConnect v73 factory RunCommand display names in per-device GSettings while preserving UUIDs, command lines, and user-renamed/custom commands.
- `ptyxis_desktop_actions.py` — deterministically reconstructs the audited Ptyxis desktop launcher with Polish names for its three GNOME Shell actions; refuses changed action lists, names, commands, or pre-existing Polish action labels.
- `ptyxis_resource_audit.py` — extracts the seven audited Ptyxis preference/profile/shortcut/custom-link GResources and requires every translatable msgid to be present in the installed Polish catalog; only three reviewed technical identity labels are allowed to equal their source.
- `generate-dhruva-emoji-pl.py`
- `inventory-extensions.sh`
- `validate-repository.py`
- `verify_ego_extension.py` — SHA-256 and strict JSON verification for pinned EGO archives.
- `prepare_github_extension_metadata.py` — strict JSON validation and deterministic metadata preparation for pinned GitHub extension sources.
- `test_extension_security.py` — negative fixtures for EGO checksum, UUID, JSON, runtime-version and GNOME compatibility enforcement.
- `test_github_metadata_security.py` — negative fixtures for pinned GitHub metadata handling.
- `verify-ding-system-monitor-menu.sh` — validates the exact DING v97 System Monitor action/menu integration and required desktop file.
- `test_ding_system_monitor_menu.py` — static fixture and integration-contract tests for the DING System Monitor customization.
- `test_tailscale_firewall_policy.py` — exact-state, fallback-isolation and rollback fixtures for the dedicated Tailscale firewalld zone.

Do not add ad-hoc one-off scripts unless they are part of the documented restore, audit, or validation workflow.
