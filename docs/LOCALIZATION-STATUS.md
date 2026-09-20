# Polish localization status

This document tracks Polish localization coverage for GNOME Shell extensions in the Fedora 44 / GNOME 50.4 workstation baseline.

The repository carries its own localization only when upstream Polish support is missing, incomplete for the tested version, or user-visible strings are not exposed through a usable upstream Polish gettext path. Existing upstream translations remain attributed to their original projects and translators.

## Repository-managed localization

Repository-managed localization/integration currently covers:

- Desktop Icons NG (DING)
- Brightness control using ddcutil
- Just Another Search Bar
- Monitor Smart Saver
- Dhruva
- Background Logo
- Browser Switcher
- GSConnect v72 completion and Shell gettext-domain fix
- Tiling Shell v76 / 17.3 completion overlay
- Just Perfection v37 full Polish localization
- Spotlight v15 / 2026.15 Polish localization and gettext integration
- Space Bar v39 controlled Polish localization
- Vitals v85 Polish completion overlay
- ddterm v72 Polish completion plus localized metadata description
- Advanced Media Controller v31 / 6.5 full Polish catalog
- Papers 49.8 / Nautilus document-properties completion overlay
- Plymouth offline-update Polish locale persistence in initramfs
- Ptyxis 50.1 Polish main-domain bridge for libadwaita About-dialog localization

Dhruva remains the largest accepted case: 393 gettext messages, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

All version-specific localization installers are wired into `scripts/install-localizations.sh`. Dedicated verifiers for the version-pinned targets are wired into the main `scripts/verify.sh` so restore drift is detected instead of silently accepted.

## 2026-09-17 extension refresh

The GNOME 50 extension set was reviewed on the physical Fedora workstation. ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes remain desired-state extensions from that refresh. Freon was initially accepted during the compatibility pass but was later intentionally removed from the workstation and from desired state.

| Extension | Polish localization status | Repository action |
| --- | --- | --- |
| ArcMenu | Upstream Polish support | No duplicate translation |
| Bluetooth Battery Meter | Upstream Polish support | No duplicate translation |
| Caffeine | Upstream Polish support | No duplicate translation |
| GSConnect v72 | 11 untranslated entries plus Shell domain issue | Completion overlay + metadata domain fix |
| Tiling Shell v76 / 17.3 | 15 untranslated entries | Completion overlay |
| User Themes | Shared GNOME Shell Extensions Polish support | No duplicate translation |
| Freon | Upstream Polish support | Removed from desired state |

## GSConnect v72

The exact v72 Polish catalog audit found **11 untranslated entries and 0 fuzzy entries**. The repository carries a minimal completion overlay rather than a duplicate full upstream catalog.

Runtime testing exposed an additional integration problem: GSConnect v72 ships the Polish catalog as `org.gnome.Shell.Extensions.GSConnect.mo`, but its extension metadata omitted `gettext-domain`. GNOME Shell 50 therefore used the wrong domain for Shell-side strings. The repository installer sets:

```json
"gettext-domain": "org.gnome.Shell.Extensions.GSConnect"
```

After logout/login, Quick Settings strings were confirmed translated on the physical workstation. The dedicated verifier checks both the merged Polish catalog and metadata domain.

## Tiling Shell v76 / 17.3

The installed extension reports numeric version **76**, version name **17.3**, gettext domain `tilingshell`, and GNOME Shell 45–50 support.

The exact upstream Polish 17.3 catalog audit found **15 untranslated entries and 0 fuzzy entries**. The repository carries a minimal `localization/tiling-shell/pl.po` completion overlay pinned to this tested version. The installer preserves the upstream catalog, merges only the missing entries, and refuses to apply the overlay after version drift. The dedicated verifier requires zero untranslated and zero fuzzy entries.

The completion installer and verifier passed on the physical Fedora 44 / GNOME 50.4 workstation, and the affected preferences were visually checked.

## Just Perfection v37

The installed physical-host extension reports **Just Perfection v37** and gettext domain `just-perfection`.

Upstream does not provide complete Polish coverage for this baseline. The repository carries `localization/just-perfection/pl.po` plus a small `v37-additions.po` for strings present in the actual v37 UI but absent from the stale upstream template.

`scripts/install-just-perfection-localization.sh` is pinned to v37 and installs the merged catalog. `scripts/verify-just-perfection-localization.sh` checks the installed version, gettext domain, repository catalog completeness, required v37-only strings, and installed `.mo` artifact.

The translation was installed and visually checked on the physical workstation.

## Spotlight v15 / 2026.15

The physical workstation reports **Spotlight v15**, version name **2026.15**. The audited upstream source does not provide a locale tree, Polish catalog, or `gettext-domain`; preferences strings are embedded directly in source.

The repository therefore carries a controlled exact-version localization. `localization/spotlight/pl.po` contains the audited Polish strings, four source patches expose the preferences UI through gettext, and `scripts/install-spotlight-localization.sh` adds `"gettext-domain": "spotlight"`, compiles `spotlight.mo`, and keeps a version-specific pristine backup.

`scripts/verify-spotlight-localization.sh` reconstructs the expected patched source, validates the gettext domain and installed catalog, and requires **22 translated entries**. The preferences UI was visually checked after logout/login.

## Space Bar v39

The physical workstation reports **Space Bar v39** (`space-bar@luchrioh`). The audited upstream v39 release supports GNOME 50 but does not provide a gettext catalog/localization tree for the user-visible strings audited in this project.

The repository uses a controlled exact-version source replacement strategy. The accepted mapping contains **109 translated source patterns** across six files covering Behavior, Appearance, Shortcuts, shortcut dialogs, Custom Styles, and the runtime panel menu.

`scripts/install-space-bar-localization.sh` validates the exact v39 fingerprints, creates a version-specific pristine backup, refuses to overwrite unknown same-version builds, applies the repository mapping, and verifies the installed result. `scripts/verify-space-bar-localization.sh` rebuilds the expected localized files from the pristine backup and compares every managed file byte-for-byte with the live extension.

The translated UI was confirmed working on the physical workstation.

## Vitals v85

The installed physical-host extension reports **Vitals v85** and gettext domain `vitals`.

The packaged upstream Polish catalog contained fuzzy or missing entries that left user-visible strings such as `Temperature`, `Storage`, `Appearance`, threshold-color controls, icon-style controls, and preference-page headings untranslated. The repository carries `localization/vitals/v85-completion.po`, currently containing the audited completion set for the tested v85 build.

`scripts/install-vitals-localization.sh` is pinned to the exact v85 metadata and source fingerprints plus the original upstream Polish `.mo` fingerprint. It creates a pristine upstream backup, merges the repository completion, and installs the resulting catalog. `scripts/verify-vitals-localization.sh` reconstructs the merge and compares it with the live `.mo` byte-for-byte.

The Vitals panel menu and preferences were visually checked on the physical Fedora workstation after the completion was installed.

## ddterm v72

The physical workstation reports **ddterm v72**, version string `63.2.3 4f64fbe89`, with gettext domain `ddterm@amezin.github.com`.

The upstream Polish catalog leaves `About ddterm` fuzzy, so gettext falls back to English. In addition, the About-window description comes directly from `metadata.json` rather than from the gettext catalog. The repository therefore carries a one-entry completion overlay plus an exact-version metadata-description localization.

`scripts/install-ddterm-localization.sh` validates the audited v72 fingerprints, stores pristine metadata and Polish catalog backups, merges the single gettext completion, and writes the localized description. `scripts/verify-ddterm-localization.sh` reconstructs both artifacts and compares them with the live installation.

## Advanced Media Controller v31 / 6.5

The workstation reports **Advanced Media Controller v31**, version name **6.5**, UUID `advanced-media-controller@sanjai.com`, and gettext domain `advanced-media-controller`. The active release supports GNOME Shell 45–50.

The tested v31 archive ships compiled translations for multiple languages but no Polish catalog. The repository therefore carries a full Polish gettext catalog in `localization/advanced-media-controller/pl.po`, generated against the exact v31 string template stored in `localization/advanced-media-controller/v31.pot`.

The Polish catalog contains **276 translated entries**. The installer and verifier are pinned to the physical-host v31 fingerprints:

- `metadata.json`: `ed5afc509700e3f0d7a158ccc1969407b44f7cbeb8ef46366eeeec2eccaa196c`
- `extension.js`: `2582e6c0cd90f44f7dfb9eb8313c9dfca0d718a55f59aedf0307857d3e80a275`
- `prefs.js`: `225c05e48f57cfd9f1c8cf5573600b588179de799bbe5d359c5fb6ecfddd9d0d`

`scripts/install-advanced-media-controller-localization.sh` validates version 31 / 6.5, the gettext domain, those fingerprints, the catalog against the v31 POT, and completeness before compiling `advanced-media-controller.mo`.

`scripts/verify-advanced-media-controller-localization.sh` performs the same version/source checks, requires exactly 276 translated entries, compares a freshly compiled repository catalog with the live `.mo`, and performs a runtime gettext smoke test requiring `General` to resolve to `Ogólne` under Polish locale selection.

The final corrected catalog was installed on the physical Fedora workstation and the Advanced Media Controller preferences were visually confirmed in Polish.

## System UI localization added on 2026-09-20

### Ptyxis 50.1 / libadwaita About dialog

The Fedora 44 workstation uses `ptyxis-50.1-2.fc44` with `libadwaita-1.9.4-1.fc44`. The installed Polish `libadwaita.mo` already contains correct translations for `_Website`, `_Report an Issue`, `_Troubleshooting`, `_Credits`, and `_Legal`, but the Fedora Ptyxis package does not ship `/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo`.

Runtime testing confirmed that creating a minimal Polish catalog for the main `ptyxis` gettext domain immediately allows the libadwaita About dialog to use those existing Polish translations. The repository therefore carries `localization/ptyxis/pl.po` as a small compatibility bridge instead of modifying `libadwaita.mo`.

`scripts/install-ptyxis-localization.sh` is pinned to Ptyxis 50.1, installs the repository catalog, preserves any pre-existing catalog as an upstream backup, restores SELinux context when available, and performs a gettext smoke test. `scripts/verify-ptyxis-localization.sh` checks the exact package version, byte-for-byte repository catalog state, the active Polish Ptyxis domain, and the five required libadwaita About-dialog translations.

The physical workstation visually confirmed the corrected About dialog: `Strona programu`, `Zgłoś błąd`, `Rozwiązywanie problemów`, `Zasługi`, and `Kwestie prawne`.

### Papers 49.8 / Nautilus document properties

The Fedora 44 workstation uses `papers-nautilus 49.8-1.fc44` for the document-properties page exposed inside Nautilus. Runtime inspection confirmed that `libpapers-document-properties.so` uses `g_dgettext` with the `papers` domain, while the installed Polish `papers.mo` lacked the affected labels.

The repository carries a minimal completion overlay in `localization/papers/pl-overlay.po`. The installer is pinned to Papers 49.8, preserves the existing Fedora catalog, merges the reviewed missing entries, and installs the rebuilt `papers.mo`. The dedicated verifier checks the package version, repository overlay, and exact translated values in the live catalog.

The physical workstation visually confirmed the completed document-properties UI, including `Właściwości dokumentu`, `Lokalizacja`, `Twórca`, `Liczba stron`, and the remaining audited labels.

### Plymouth offline updates

Fedora's installed Plymouth catalog already contains correct Polish translations for `Installing Updates...`, `Do not turn off your computer`, and `%d%% complete`. The untranslated offline-update screen was traced to the initramfs: Plymouth, `two-step.so`, and the `bgrt` theme were present, while the Polish locale data, `/etc/locale.conf`, and `plymouth.mo` were absent.

The repository therefore does not duplicate Plymouth translations. Instead, `localization/plymouth/55-polish-plymouth.conf` records the tested dracut `install_items` set. `scripts/install-plymouth-localization.sh` installs that persistent dracut configuration, rebuilds the current initramfs when required, and validates the required locale and gettext artifacts. `glibc-langpack-pl` is an explicit RPM dependency so the small per-language locale tree is used instead of embedding the 223 MiB global locale archive.

The rebuilt physical-host initramfs grew only from about 156 MiB to 157 MiB, booted successfully on kernel `7.2.5-200.fc44.x86_64`, and `systemctl --failed` reported zero failed units. Final visual confirmation of the translated offline-update screen remains pending until the next real offline update.

## GNOME system-extension audit

### Launch New Instance

`launch-new-instance@gnome-shell-extensions.gcampax.github.com` is supplied by Fedora's GNOME Shell Extensions package. The exact GNOME 50 runtime has no interactive preferences UI and no user-visible runtime strings requiring a repository translation. **No repository localization is required.**


## Physical verification state

Before the Ptyxis bridge was integrated, the physical Fedora 44 / GNOME 50.4 workstation completed the latest full-system acceptance run with:

```text
PASS=230 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

The Ptyxis runtime fix was then visually validated on the same workstation. A new full `scripts/verify.sh` run is required after pulling this integration before the accepted full-system counter is advanced beyond 230.

The historical clean-room VM result remains unchanged:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

## Maintenance policy

Repository-managed translations are version-scoped. Whenever an accepted extension version changes, upstream Polish coverage and source layout must be re-audited before the repository overlay is considered valid for the new release.

Where upstream already provides complete Polish support, this repository should not carry a redundant duplicate translation. Where upstream support is incomplete, the repository should prefer minimal completion overlays. Where no localization mechanism exists, controlled exact-version source localization may be used only with strict fingerprinting, backups, deterministic verification, and physical UI validation.
