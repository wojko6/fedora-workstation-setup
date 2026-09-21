# Scripts index

The scripts directory contains the operational entrypoints used to build, restore, audit, and verify the Fedora workstation desired state.

## Primary entrypoints

- `check-static.sh` — repository-only validation used locally and by GitHub Actions.
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
- `install-launchers.sh`
- `install-weather-locations.sh` — restores reviewed custom GNOME Weather locations in the user session.
- `install-dhruva-config.sh`
- `manage-weather-locations.py` — libgweather-backed installer/verifier for reviewed custom GNOME Weather locations.

The top-level `install.sh` orchestrates these stages. Individual stages should remain safe to inspect and, where practical, safe to rerun.

## Localization

`install-localizations.sh` is the single localization pipeline. It invokes all 12 version-specific GNOME-extension localization installers, the simpler catalog installs managed directly from `localization/`, and the system-level Papers/Nautilus, Plymouth, and Ptyxis localization stages.

Dedicated `verify-*-localization.sh` scripts validate exact-version, completion-overlay, and system-localization targets and are wired into `verify.sh`.

The Bluetooth Battery Meter helper pair installs and verifies the v46/v49 BudsLink Companion completion overlay:

- `install-bluetooth-battery-meter-localization.sh`
- `verify-bluetooth-battery-meter-localization.sh`
- `install-clipboard-indicator-localization.sh` / `verify-clipboard-indicator-localization.sh` — Clipboard Indicator v71 63-entry Polish completion over the audited upstream catalog.
- `install-blur-my-shell-localization.sh` / `verify-blur-my-shell-localization.sh` — Blur my Shell v72 61-entry Polish completion plus two pipeline UI source patches over the audited physical EGO build.

- `install-extension-manager-localization.sh` / `verify-extension-manager-localization.sh` — Extension Manager 0.6.5 Flatpak Locale one-entry contextual completion (`None` → `Brak`) pinned to the audited Locale commit and pristine catalog hash.

System localization helpers:
- `install-papers-localization.sh` / `verify-papers-localization.sh` — Papers 49.8 / Nautilus Polish completion for confirmed document-properties, annotations-sidebar, and empty-start-page gaps.
- `install-plymouth-localization.sh` / `verify-plymouth-localization.sh` — Fedora 44 Plymouth offline-update Polish locale persistence through dracut.
- `install-ptyxis-localization.sh` / `verify-ptyxis-localization.sh` — Ptyxis 50.1 Polish main-domain bridge enabling existing libadwaita About-dialog translations.

## GNOME Keyring i18n

- `build-gnome-keyring-i18n-backport.sh` — reproducible Fedora 44 / GNOME Keyring 50.0 gettext backport build.
- `verify-gnome-keyring-i18n.sh` — runtime/package/catalog verification.

## Generators and helpers

- `apply-space-bar-localization.py`
- `generate-dhruva-emoji-pl.py`
- `inventory-extensions.sh`
- `validate-repository.py`
- `verify_ego_extension.py` — SHA-256 and strict JSON verification for pinned EGO archives.
- `prepare_github_extension_metadata.py` — strict JSON validation and deterministic metadata preparation for pinned GitHub extension sources.
- `test_extension_security.py` — negative fixtures for EGO checksum, UUID, JSON, runtime-version and GNOME compatibility enforcement.
- `test_github_metadata_security.py` — negative fixtures for pinned GitHub metadata handling.

Do not add ad-hoc one-off scripts unless they are part of the documented restore, audit, or validation workflow.
