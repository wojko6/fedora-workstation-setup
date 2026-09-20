# Localization sources

This directory contains repository-owned Polish translation sources and controlled completion data for the tested GNOME extension baseline.

The repository adds localization only when upstream Polish support is missing, incomplete, stale for the tested release, or not exposed through a usable gettext path.

## Strategy

- Normal gettext targets use reviewed `.po` sources.
- Completion-only targets carry the minimal missing entries.
- Space Bar v39 uses controlled exact-version source replacements.
- Spotlight v15 / 2026.15 uses gettext wiring plus source patches.
- Dhruva combines a gettext catalog, source patches, and generated Polish CLDR emoji metadata.
- Advanced Media Controller v31 / 6.5 carries a complete Polish catalog pinned to the audited release.
- Bluetooth Battery Meter v46/v49 uses a minimal completion overlay for the 16 untranslated messages on the BudsLink Companion preferences page.
- Papers / Nautilus uses a minimal completion overlay merged into Fedora's installed `papers.mo` for the audited Papers 49.8 build, covering confirmed gaps in document properties, the annotations sidebar, and the empty start page.
- Plymouth keeps Fedora's upstream Polish translations and makes the early-boot/offline-update locale reproducible by installing the required Polish locale data and gettext catalog into initramfs through dracut.
- Ptyxis 50.1 uses a minimal Polish main-domain catalog because Fedora's package does not ship `pl/LC_MESSAGES/ptyxis.mo`; activating the main domain allows GLib/libadwaita to use their existing Polish About-dialog translations without modifying `libadwaita.mo`.

All localization installation is centralized through `scripts/install-localizations.sh`, including the system-level Papers, Plymouth, and Ptyxis targets. Verification is integrated into `scripts/verify.sh`.

See [../docs/LOCALIZATION-STATUS.md](../docs/LOCALIZATION-STATUS.md) for the accepted versions, coverage, and runtime validation details.
