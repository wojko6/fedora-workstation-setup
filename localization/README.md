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
- Blur my Shell v72 uses a 61-entry completion plus two exact-version pipeline UI source patches, covering all 54 untranslated upstream catalog messages and seven pipeline/UI strings missed by the effective upstream extraction path.
- Clipboard Indicator v71 uses a 64-entry completion overlay covering all 41 untranslated and 23 fuzzy entries from the exact audited upstream `v71` Polish catalog. A physical visual check found the one fuzzy description previously omitted by the 63-entry audit, and the verifier now smoke-tests it explicitly.
- Extension Manager 0.6.5 uses a one-entry contextual completion (`Sort search results` / `None` → `Brak`) merged into the exact audited Flatpak Locale catalog.
- Helium 0.17.2.1 uses a 36-entry Linux-relevant JSON completion applied to Chromium DataPack v5 `pl.pak`; the patcher preserves all unmanaged resource bytes semantically, refuses changed audited strings in strict mode, and is re-run after `helium-bin` package transactions through DNF5 actions.
- GNOME Tweaks 49.0 uses a one-line source patch so generated GSettings enum labels pass through gettext, plus a 12-entry Polish overlay: 11 generated enum completions and the reviewed `Hinting` → `Dopasowanie do pikseli` terminology override.
- Ptyxis 50.1 uses a version-pinned Polish main-domain completion because Fedora's package does not ship `pl/LC_MESSAGES/ptyxis.mo`. In addition to the already audited main window/menu, terminal context menu, search/inspector, title dialog, and search options, the 2026-09-24 physical audit first added 152 unique missing strings covering the preferences, profile editor/dialog/row, and shortcut dialog/row resources. A later visual check exposed six more unique custom-link gaps: five strings in `ptyxis-custom-link-editor.ui` plus the C-generated `Add Link` label. Follow-up screenshots then exposed three more C-generated preference labels (`Add Profile`, `Show Fewer Palettes`, `Select Font`) and the translatable palette-preview pangram. The managed completion therefore adds 162 unique strings from this audit cycle. The installer/verifier now scan eight exact embedded UI resources and require zero unresolved resource strings, with only `Terminal`, `Control-H`, and `ASCII DEL` accepted as reviewed identity translations; the four C-generated labels are checked separately through gettext. The same stage patches the audited `org.gnome.Ptyxis.desktop` actions with `Name[pl]` values for `New Window`, `New Tab`, and `Preferences`, pinned to pristine SHA-256 `8c596c2aff40ac062f61e6c541f0bccfa62091ce8503d63e2306d2e0a97f2b88`.

All localization installation is centralized through `scripts/install-localizations.sh`: four generic gettext targets, 15 specialized GNOME-extension stages, plus Papers, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks application/system stages (**25 localization targets/operations total**). Verification is integrated into `scripts/verify.sh`. VSCodium is intentionally deferred and is not part of the current reproducible localization set.

See [../docs/LOCALIZATION-STATUS.md](../docs/LOCALIZATION-STATUS.md) for the accepted versions, coverage, and runtime validation details.
