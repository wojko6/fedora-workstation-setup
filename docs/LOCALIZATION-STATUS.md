# Polish localization status

This document tracks Polish localization coverage for GNOME Shell extensions and selected system UI components in the current Fedora 44 / GNOME 50.5 physical-workstation baseline.

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
- Bluetooth Battery Meter v46/v49 BudsLink Companion completion overlay
- Vitals v85 Polish completion overlay
- ddterm v72 Polish completion plus localized metadata description
- Advanced Media Controller v31 / 6.5 full Polish catalog
- Papers 49.8 / Nautilus document-properties completion overlay
- Plymouth offline-update Polish locale persistence in initramfs
- Ptyxis 50.1 Polish main-window/menu, terminal-context, search, inspector, title-dialog, and search-options completion plus libadwaita About-dialog localization
- Blur my Shell v72 61-entry completion plus exact-version pipeline UI patches
- Clipboard Indicator v71 63-entry completion overlay
- Extension Manager 0.6.5 contextual `None` → `Brak` completion
- Helium 0.17.2.1 36-entry Chromium DataPack v5 completion with DNF5 post-transaction persistence
- GNOME Tweaks 49.0 generated GSettings enum localization plus `Hinting` terminology override

Dhruva remains the largest accepted case: 393 gettext messages, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

`scripts/install-localizations.sh` currently invokes 15 version-specific GNOME-extension localization installers plus six application/system stages: Papers, Plymouth, Ptyxis, Extension Manager, Helium, and GNOME Tweaks. Dedicated verifiers for the version-pinned targets are wired into the main `scripts/verify.sh` so restore drift is detected instead of silently accepted.

## 2026-09-21 global physical localization audit

A broader read-only audit was run against the Fedora 44 / GNOME Shell 50.5 physical workstation to compare the actual installed locale state with the repository's managed coverage.

Confirmed good state:

- the session locale is `pl_PL.UTF-8`;
- `glibc-langpack-pl`, `langpacks-pl`, `libreoffice-langpack-pl`, and `gettext` are installed;
- GNOME Shell, Control Center, Nautilus, Weather, Boxes, Tweaks, GNOME Keyring, Papers, and firewalld expose Polish catalogs on the physical host;
- LibreOffice 26.2.6.3 has the Polish langpack and its Polish resource tree installed;
- the repository-managed Ptyxis 50.1 catalog is installed as an intentionally unowned local file and passes its dedicated verifier.

The audit also reopened localization completeness for two desired-state extensions:

- **Blur my Shell v72**: the initial runtime audit confirmed 46 single-line English fallbacks; visual follow-up then exposed eight multiline catalog gaps and pipeline-management strings outside the effective upstream catalog. The repository now carries a 61-entry completion plus two exact-version pipeline UI source patches. Physical installation, dedicated verification, and visual acceptance all pass.
- **Clipboard Indicator v71**: the physical v71 catalog fingerprint matches the audited EGO installation and contains only 49 compiled Polish messages. The exact upstream v71 source catalog has 112 entries, of which 41 are untranslated and 22 are fuzzy, leaving 63 effective runtime gaps. The repository now carries a 63-entry completion overlay plus exact-version/source/catalog fingerprint checks; physical installation and dedicated runtime/gettext verification pass. Visual UI acceptance remains a separate manual check.

Application-level follow-ups:

- **Extension Manager 0.6.5**: the separate system Flatpak Locale ref is present and provides the Polish `extension-manager.mo`. Visual inspection and exact v0.6.5 source review confirmed one application-owned untranslated contextual label: sort option `None`. The repository carries a one-entry completion (`None` → `Brak`) pinned to Locale commit `9e45ce9096c3efdcc54b26375fed9b730a6e8f5032daf6b8cee35482afacd036` and pristine catalog SHA-256 `6ea6fda169660bc791d46a74bd511cbb91a97ee6f9308bc9db7b4f3602d25a78`; physical installation, dedicated verification, and visual acceptance all pass.
- **Helium 0.17.2.1 / Chromium 153.0.8010.52**: the physical Fedora COPR RPM ships a Polish Chromium DataPack v5 at `/opt/helium/locales/pl.pak`. Exact build/source comparison found 36 Helium-specific untranslated messages relevant to Linux. The repository now carries a safe JSON completion plus a dependency-free DataPack v5 parser/writer, a versioned pristine-backup installer, a dedicated verifier, and a DNF5 `post_transaction` action that reapplies only entries that still equal their audited English source. Physical installation, dedicated verification, and visual acceptance pass on the Fedora 44 workstation.
- **VSCodium 1.135.06055**: Polish UI reproducibility is not currently demonstrated; this follow-up is intentionally deferred for now.

The audit also exposed a verifier-design issue in the Ptyxis search-options completion: the actual embedded resource uses mnemonic-bearing msgids `Match _Case`, `Whole _Words`, and `Use _Regular Expressions`. The repository catalog and verifier have been corrected to those exact resource strings, and the verifier now checks the installed Ptyxis resource before accepting the translations.

The repository-managed localization fixes discovered by the 2026-09-21 audit remain integrated; the current project-wide full physical verifier now completes at `PASS=249 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0` after the later DING System Monitor desktop-menu integration was added and accepted. VSCodium remains intentionally deferred and is therefore outside the reproducible localization claim; a clean verifier result must not be interpreted as proof that every third-party UI string on the workstation is translated.

## 2026-09-17 extension refresh

The GNOME 50 extension set was reviewed on the physical Fedora workstation. ArcMenu, Bluetooth Battery Meter, Caffeine, GSConnect, Tiling Shell, and User Themes remain desired-state extensions from that refresh. Freon was initially accepted during the compatibility pass but was later intentionally removed from the workstation and from desired state.

| Extension | Polish localization status | Repository action |
| --- | --- | --- |
| ArcMenu | Upstream Polish support | No duplicate translation |
| Bluetooth Battery Meter v49 | 16 untranslated BudsLink Companion entries | Completion overlay + v49 restore pin |
| Caffeine | Upstream Polish support | No duplicate translation |
| GSConnect v72 | 11 untranslated entries plus Shell domain issue | Completion overlay + metadata domain fix |
| Tiling Shell v76 / 17.3 | 15 untranslated entries | Completion overlay |
| User Themes | Shared GNOME Shell Extensions Polish support | No duplicate translation |
| Freon | Upstream Polish support | Removed from desired state |

### Blur my Shell v72 completion

The physical workstation reports Blur my Shell **v72** with gettext domain `blur-my-shell@aunetx`. The audited upstream Polish catalog fingerprint on the physical EGO installation is `44073c8675b6457082d9e3d7f40e8889259def344fe03b57155a115750493e88`.

A runtime audit tested all 46 candidate gaps from the exact v72 source catalog, and every one resolved to its English msgid on the physical workstation. The missing set covers blend modes, luminosity/brightness/contrast controls, spatial-derivative operations, RGB/HSL conversion effects, corner rounding, and Coverflow Alt-Tab blur integration.

The first runtime pass found 46 single-line English fallbacks, but a subsequent visual audit exposed eight additional untranslated multiline catalog entries plus pipeline-management strings that upstream's extraction path does not cover correctly. The managed completion therefore now contains 61 entries: all 54 untranslated upstream v72 catalog messages plus seven pipeline/UI messages required by the audited physical build. Two exact-version source patches localize built-in pipeline names, the pipeline identifier label, and pluralized effect counts without changing user-defined pipeline names.

`scripts/install-blur-my-shell-localization.sh` validates v72 plus the audited `metadata.json`, `extension.js`, `prefs.js`, and pristine Polish catalog fingerprints, preserves pristine pipeline source backups, applies the two repository patches, merges the 61-entry catalog completion, and invokes the dedicated verifier. `scripts/verify-blur-my-shell-localization.sh` reconstructs both patched source files and the merged catalog, compares them with the live installation, and checks representative completed msgids through gettext.

The expanded 61-entry completion plus both pipeline source fixes have now been installed successfully on the Fedora 44 / GNOME Shell 50.5 workstation. The dedicated verifier passes with `61 entries, 0 fuzzy`, and the corrected pipeline/application UI has been visually accepted in Polish.

### Clipboard Indicator v71 completion

The physical workstation reports Clipboard Indicator **v71** with gettext domain `clipboard-indicator`. The installed upstream Polish catalog fingerprint is `312170de7c29483114d5cf41f540c66ce29fc4b273349144613af848897ab06f` and contains 49 compiled translations.

The exact v71 upstream source catalog contains 112 messages: 41 untranslated and 22 fuzzy. Because fuzzy gettext entries are not compiled into the runtime catalog, those 63 entries are effective English fallbacks on the tested installation.

The repository carries `localization/clipboard-indicator/v71-completion.po` with all 63 missing/fuzzy entries. `scripts/install-clipboard-indicator-localization.sh` is pinned to v71 and validates `metadata.json`, `extension.js`, `prefs.js`, and the pristine upstream Polish catalog fingerprint before merging. `scripts/verify-clipboard-indicator-localization.sh` reconstructs the merged catalog, requires zero untranslated and zero fuzzy entries, compares it byte-for-byte with the live catalog, and performs gettext smoke tests for representative actions and search options.

Physical installation and the dedicated runtime/gettext verification have passed on the Fedora 44 / GNOME Shell 50.5 workstation. Visual UI acceptance remains pending.

### Extension Manager 0.6.5

The physical workstation uses the system Flatpak `com.mattjakeman.ExtensionManager` version **0.6.5** and its separate `com.mattjakeman.ExtensionManager.Locale` ref. The Polish locale ref is pinned to commit `9e45ce9096c3efdcc54b26375fed9b730a6e8f5032daf6b8cee35482afacd036`; the pristine Polish `extension-manager.mo` fingerprint is `6ea6fda169660bc791d46a74bd511cbb91a97ee6f9308bc9db7b4f3602d25a78`.

A visual audit of the search page showed the application itself translated into Polish except for the sort selector value `None`. Exact v0.6.5 source inspection confirms that this is a contextual gettext entry with context `Sort search results`; extension names and descriptions shown in search results are remote metadata supplied by extension authors and are outside Extension Manager's own localization catalog.

The repository carries `localization/extension-manager/v0.6.5-completion.po` with the single contextual translation `None` → `Brak`. `scripts/install-extension-manager-localization.sh` validates the exact application version, Locale commit, and pristine catalog hash, preserves the original catalog under the user's local project backup area, merges the one-entry completion, and installs the rebuilt catalog into the system Flatpak Locale deployment. `scripts/verify-extension-manager-localization.sh` reconstructs the expected merged catalog and checks the contextual translation through Python gettext.

Because the completion is applied to a Flatpak deployment checkout, a Flatpak update or repair can replace it; the exact-version verifier detects that drift and the localization installer reapplies the controlled override after the audited Locale ref is restored.

Physical installation, dedicated verification, and final visual acceptance have passed on the Fedora 44 / GNOME Shell 50.5 workstation; the sort selector now shows `Brak` instead of `None`.

### Helium 0.17.2.1

The physical workstation uses Fedora COPR package `helium-bin-0.17.2.1-1.fc44.x86_64`, reporting **Helium 0.17.2.1 (Chromium 153.0.8010.52)**. The producer-owned Polish locale archive is `/opt/helium/locales/pl.pak`; before repository changes its SHA-256 is `93b0489811a30c4005294b192b6cadbd4089ab29da9e167fa40f48a2320940a6`, and RPM verification reports the package as pristine.

The audited archive is Chromium **DataPack v5**, UTF-8, with 11,820 resource entries and 2,478 aliases. The Helium source tree for the exact Linux build points to commit `8c19f4c6d624e31293bca13e655f2fe542ba6fdb`. Comparing that build's `i18n/source.gen.json` with `i18n/translations/pl.json` finds 38 missing Helium-specific Polish entries; two are macOS-only, leaving **36 Linux-relevant gaps**. All 36 names were confirmed in the physical `pl.pak.info` and their runtime payloads were confirmed to be the audited English source strings.

The repository carries `localization/helium/v0.17.2.1-pl-completion.json` with those 36 translations. `scripts/helium_datapack.py` implements the documented Chromium DataPack v5 layout in pure Python, including alias parsing/reconstruction, deterministic UTF-8 output, semantic round-trip validation, and a synthetic self-test. It changes only resource IDs whose current payload exactly matches the audited English source; unexpected producer values are left untouched. Strict mode additionally pins the physical 0.17.2.1 resource IDs.

`scripts/install-helium-localization.sh` installs the DataPack helper, completion data, and root transaction helper under `/usr/local`, installs `libdnf5-plugin-actions` when required, and installs `system/dnf5/actions.d/90-helium-localization.actions`. The DNF5 action runs after incoming `helium-bin` package transactions. The transaction helper keeps a pristine, versioned producer backup in `/var/lib/fedora-workstation-setup/helium/<version>/`, rebuilds the Polish DataPack from that backup, and replaces the live `pl.pak` atomically so an already-running browser can keep the old mapped inode safely.

For future Helium versions, the post-transaction helper deliberately does **not** force old Polish text over changed producer strings. It patches only entries whose payload still equals the audited English source and warns that a new full localization audit is required. The full `scripts/verify-helium-localization.sh` remains version-pinned to 0.17.2.1 so an update cannot be silently accepted as fully reviewed.

Physical installation, dedicated verification, and visual acceptance have passed on the Fedora 44 workstation.

### GNOME Tweaks 49.0

The physical workstation uses **gnome-tweaks-49.0-2.fc44.noarch**. Most of its interface is correctly translated upstream, but the generic `build_gsettings_list_store()` helper converts raw enum values such as `toggle-maximize`, `none`, and `zoom` into title case without passing them through gettext. This leaves generated combo-box values in English even when the Polish catalog already contains an applicable translation such as `None` → `Brak`.

The audited Fedora source fingerprints are:

- `gtweak/widgets.py`: `2d1cba580bbfe37fd06244c76895f81c4358c2a2e2ece8c27a81cf0302d1ddca`
- `gtweak/tweaks/tweak_group_windows.py`: `df8810db18925c852640c4bff8885f30a71daa7561f8765b06f53f891d7e3b17`
- upstream Polish `gnome-tweaks.mo`: `b6b9ec6189ff735a635cbc31aa6a709291a90ee73046970a185f136855209b65`

The repository carries a one-line source patch that changes generated GSettings titles from plain title-cased strings to gettext lookups. The existing upstream catalog then supplies labels it already knows (`None`, `Minimize`), while `localization/gnome-tweaks/v49.0-gsettings-enums.po` provides 11 reviewed Polish labels for the remaining audited window-action and background-adjustment values. A later visual audit of the Fonts page found upstream Polish deliberately leaving the visible `Hinting` label unchanged; the same overlay now also overrides it as `Dopasowanie do pikseli`, for 12 managed entries total.

`scripts/install-gnome-tweaks-localization.sh` is pinned to the exact Fedora NEVRA, preserves pristine source and catalog backups under `/var/lib/fedora-workstation-setup/gnome-tweaks/49.0-2.fc44/`, reconstructs the patched `widgets.py` and merged catalog in a temporary directory, and only then installs both artifacts. `scripts/verify-gnome-tweaks-localization.sh` reconstructs both expected files from the pristine backups and compares them byte-for-byte with the live installation, in addition to gettext smoke tests for the generated labels.

A future GNOME Tweaks package version/release is intentionally not auto-accepted: the exact-package verifier will fail until the new source and Polish catalog are re-audited.

The generated GSettings-value fix is installed and visually accepted on the physical workstation: the previously visible `Toggle Maximize` / `None` / related enum values now resolve through Polish gettext. The final `Hinting` → `Dopasowanie do pikseli` terminology override has also been reinstalled and visually confirmed on the physical workstation.

## Bluetooth Battery Meter v46/v49

The physical workstation reports **Bluetooth Battery Meter v49**, UUID and gettext domain `Bluetooth-Battery-Meter@maniacx.github.com`. The reproducible extension inventory and source lock now also record v49. The existing Polish catalog translates the main extension preferences, but leaves all **16 messages** on the BudsLink Companion page untranslated, including the introduction, integration controls, installation states, and documentation links.

The repository carries a minimal completion overlay in `localization/bluetooth-battery-meter/v46-budslink-completion.po`; the legacy filename is retained for history, while the same audited 16-message completion is accepted for v49. `scripts/install-bluetooth-battery-meter-localization.sh` accepts the locked v46 build and the active v49 build, then validates the gettext domain and every exact BudsLink source message before preserving a version-specific copy of the prior Polish catalog and merging the reviewed entries. `scripts/verify-bluetooth-battery-meter-localization.sh` reconstructs the expected merged catalog, compares it byte-for-byte with the live installation, and checks every completed translation through gettext.

The completion is limited to the demonstrated BudsLink gap; existing upstream Polish translations elsewhere in the extension remain unchanged. The exact EGO v49 archive is pinned with SHA-256 `53efe7719a55376ba7fdcaf5a837ec3567804489d39446f26bec881e85dd5afc`, so clean restore now reproduces the accepted v49 runtime instead of downgrading to v46.

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

### Ptyxis 50.1 main window/menu + libadwaita About dialog

The Fedora 44 workstation uses `ptyxis-50.1-2.fc44` with `libadwaita-1.9.4-1.fc44`. The installed Polish `libadwaita.mo` already contains correct translations for `_Website`, `_Report an Issue`, `_Troubleshooting`, `_Credits`, and `_Legal`, but the Fedora Ptyxis package does not ship `/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo`.

The first repository bridge activated the main `ptyxis` gettext domain and fixed the libadwaita About dialog, but a subsequent physical UI audit showed that the primary Ptyxis menu still fell back to English for entries such as `New Tab`, `New Window`, `Show Open Tabs`, `Fullscreen`, `Preferences`, and `Keyboard Shortcuts`. The repository catalog has therefore been expanded into a version-pinned main-window/menu completion while retaining the existing libadwaita integration.

`scripts/install-ptyxis-localization.sh` remains pinned to Ptyxis 50.1, installs the repository catalog, preserves a pre-existing package-owned catalog as an upstream backup, replaces unowned/local test catalogs without mislabeling them as upstream, restores SELinux context when available, and now smoke-tests the audited primary-menu translations. `scripts/verify-ptyxis-localization.sh` checks the exact package version, byte-for-byte repository catalog state, the required Ptyxis menu translations, and the five required libadwaita About-dialog translations.

The earlier About-dialog fix was visually confirmed on the physical workstation. The expanded main-window/menu completion was then installed, its dedicated verifier passed, and after restarting Ptyxis the primary menu was visually confirmed in Polish, including `Nowa karta`, `Nowe okno`, `Pokaż otwarte karty`, `Pełny ekran`, `Preferencje`, `Skróty klawiszowe`, and `O programie`.

A later physical audit of the terminal right-click menu exposed a second coverage gap. The exact embedded `/org/gnome/Ptyxis/ptyxis-terminal.ui` resource from `ptyxis-50.1-2.fc44` was inspected and showed untranslated terminal-menu labels and descriptions including `Search…`, link/copy/paste actions, selection actions, `Read-Only`, reset actions, profile switching, and `_Inspect Terminal`. The repository catalog and both the installer smoke test and dedicated verifier now cover the complete audited terminal context-menu message set. Physical UI confirmation of this final context-menu completion is pending. A subsequent physical audit also found the search-bar placeholder `Search History` and the built-in terminal inspector (`Process`, `Appearance`, `Input`, process/path metadata, grid/palette/font data, cursor/mouse data, and related status values) still untranslated. Those exact Ptyxis-domain strings are now included in the repository catalog and in installer/verifier smoke tests; final physical UI confirmation of the search bar and inspector remains pending. The `Set Title` dialog was also found to contain untranslated `Title`, `Include Process Title`, and `Append title from Shell application` strings; these are now covered by the same version-pinned catalog and smoke tests. The search-options popover was also found to leave `Match Case`, `Whole Words`, and `Use Regular Expressions` in English; these exact strings are now included in the same catalog and verifier.

### Papers 49.8 / Nautilus completion overlay

The Fedora 44 workstation uses Papers 49.8 and `papers-nautilus 49.8-1.fc44`. Runtime inspection confirmed that the Nautilus document-properties extension uses the `papers` gettext domain, while source inspection of the exact Papers 49.8 tag confirmed that the viewer's `No Annotations` status-page title and the empty-start-page strings `Open a Document`, `Drag and drop documents here`, and `_Open…` use the same domain without message contexts. The installed Polish `papers.mo` lacked these affected labels.

The repository carries a minimal completion overlay in `localization/papers/pl-overlay.po`. It uses `Brak przypisów` for `No Annotations`, matching the existing Polish terminology for `Annotations`, `Annotation Properties`, and `Remove Annotation`, and completes the start page with `Otwórz dokument`, `Przeciągnij i upuść dokumenty tutaj`, and `_Otwórz…`. The installer is pinned to both the Papers and papers-nautilus 49.8 packages, preserves the existing Fedora catalog, merges the reviewed missing entries, and installs the rebuilt `papers.mo`. The dedicated verifier checks package versions, the repository overlay, and exact translated values in the live catalog.

The physical workstation visually confirmed the completed document-properties UI, including `Właściwości dokumentu`, `Lokalizacja`, `Twórca`, `Liczba stron`, and the remaining audited labels, as well as `Brak przypisów` in the annotations sidebar. The empty start page was subsequently completed and visually confirmed with `Otwórz dokument`, `Przeciągnij i upuść dokumenty tutaj`, and `_Otwórz…`.

### Plymouth offline updates

Fedora's installed Plymouth catalog already contains correct Polish translations for `Installing Updates...`, `Do not turn off your computer`, and `%d%% complete`. The untranslated offline-update screen was traced to the initramfs: Plymouth, `two-step.so`, and the `bgrt` theme were present, while the Polish locale data, `/etc/locale.conf`, and `plymouth.mo` were absent.

The repository therefore does not duplicate Plymouth translations. Instead, `localization/plymouth/55-polish-plymouth.conf` records the tested dracut `install_items` set. `scripts/install-plymouth-localization.sh` installs that persistent dracut configuration, rebuilds the current initramfs when required, and validates the required locale and gettext artifacts. `glibc-langpack-pl` is an explicit RPM dependency so the small per-language locale tree is used instead of embedding the 223 MiB global locale archive.

The rebuilt physical-host initramfs grew only from about 156 MiB to 157 MiB, booted successfully on kernel `7.2.5-200.fc44.x86_64`, and `systemctl --failed` reported zero failed units. Final visual confirmation of the translated offline-update screen remains pending until the next real offline update.

## GNOME system-extension audit

### Launch New Instance

`launch-new-instance@gnome-shell-extensions.gcampax.github.com` is supplied by Fedora's GNOME Shell Extensions package. The exact GNOME 50 runtime has no interactive preferences UI and no user-visible runtime strings requiring a repository translation. **No repository localization is required.**


## Physical verification state

After the 2026-09-21 audit-driven localization additions were integrated, the physical Fedora 44 / GNOME Shell 50.5 workstation completed a fresh full `scripts/verify.sh` acceptance run from the canonical repository checkout with:

```text
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current accepted physical-host localization baseline for the controls implemented by the repository. Helium and GNOME Tweaks are physically accepted, including the final `Hinting` → `Dopasowanie do pikseli` override; Extension Manager is visually accepted; Blur my Shell is visually accepted; Clipboard Indicator passes its dedicated installation/runtime/gettext verification; Papers / Nautilus is visually accepted; and Plymouth's initramfs state is technically verified. Final visual confirmation of the Plymouth offline-update screen remains pending until a real offline update occurs. VSCodium remains intentionally deferred and outside the reproducible localization claim.

The historical clean-room VM result remains unchanged:

```text
PASS=147 WARN=0 FAIL=0 SKIP=8
```

## Maintenance policy

Repository-managed translations are version-scoped. Whenever an accepted extension version changes, upstream Polish coverage and source layout must be re-audited before the repository overlay is considered valid for the new release.

Where upstream already provides complete Polish support, this repository should not carry a redundant duplicate translation. Where upstream support is incomplete, the repository should prefer minimal completion overlays. Where no localization mechanism exists, controlled exact-version source localization may be used only with strict fingerprinting, backups, deterministic verification, and physical UI validation.
