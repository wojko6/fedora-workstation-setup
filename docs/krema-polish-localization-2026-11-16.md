# Krema 0.13.0 — Polish localization discovery and safe deployment plan (2026-11-16)

> **Status:** source-reviewed, user-local `krema.mo` installed and **Polish UI visually confirmed by the operator**; bounded acceptance, not exhaustive visual review of all entries.
> **Target:** Fedora 45 / KDE Plasma 6.8.2 / Wayland; installed Krema 0.13.0. Do not modify the COPR RPM or the package-managed `/usr` tree.

## Evidence from the exact upstream release

Source: [isac322/krema v0.13.0](https://github.com/isac322/krema/tree/v0.13.0). The tagged `src/main.cpp` calls `KLocalizedString::setApplicationDomain("krema")`; `src/CMakeLists.txt` links KF6 I18n and I18nQml. KDE translations are used in C++ and QML via `i18n()`/`i18nc()`.

Checked callsites include:

- `src/models/dockcontextmenu.cpp`: exact `@action:inmenu` messages `Pin to Dock`, `Unpin from Dock`, `New Instance`, `Clear Notifications`, `Close`, `Settings...`, `About Krema`, `Quit Krema`.
- `src/qml/SettingsDialog.qml`: `Settings`, `Search settings`, eight principal settings pages and their search keywords.
- `src/qml/settings/{IconsPage,LayoutPage,PanelStylePage,ShadowPage,AnimationsPage,BehaviorPage,MonitorsPage,PreviewPage}.qml`: dozens of options, descriptions, preview labels and accessibility strings.
- `src/qml/{main,DockItem,PreviewPopup,PreviewThumbnail}.qml`: task state, badge, preview and accessibility text.

An earlier user-local `.desktop` Polish override translated the application name/description only. It is **not** a translation of the live C++/QML strings.

## Preferred architecture

1. Create a `pl` PO catalog whose message IDs and contexts match **exact v0.13.0 source strings**. Retain placeholders `%1`, `%2`, markup and plural forms; do not translate user application names.
2. Run `msgfmt --check` and compile `krema.mo`. Use a **user-local** catalog, e.g. `$HOME/.local/share/locale/pl/LC_MESSAGES/krema.mo`, keeping a byte-for-byte backup if a file already exists. Confirm lookup in the active KDE session before any persistent launcher change.
3. Restart **Krema only after** the operator saves their session state. Do not kill Plasma, wipe dock configuration, overwrite `kremarc`, replace the COPR RPM or alter theme visuals merely to localize UI.
4. Verify the dock's right-click menu, the settings sidebar, each settings page, previews, accessibility labels and plural strings. Log untranslated items, exact source contexts and mismatches. `PO_COMPLETE` is not synonymous with `UI_COMPLETE`.
5. Preserve a guarded rollback and document an update compatibility gate before installing against later upstream Krema releases.

## Translation review examples

| Exact upstream message | Proposed Polish | Source/context |
| --- | --- | --- |
| Pin to Dock | Przypnij do docka | `@action:inmenu` |
| Unpin from Dock | Odepnij od docka | `@action:inmenu` |
| Settings... | Ustawienia… | `@action:inmenu` |
| New Instance | Nowa instancja | `@action:inmenu` |
| Quit Krema | Zakończ Kremę | `@action:inmenu` |
| Behavior | Zachowanie | QML |
| Layout & Position | Układ i położenie | QML |
| Window Preview | Podgląd okien | QML |
| Separate pinned and running apps | Oddziel przypięte i uruchomione aplikacje | QML |

## 2026-11-16 v0.1 catalog artifact checkpoint

A separate Polish pilot archive was generated and subsequently installed by the operator: `krema-pl-v0130-v01.zip`, containing an editable `krema.po` (**268 source-reviewed context/message entries**), a user-scope installer/rollback script and Polish operator README. In an isolated local harness, the script self-test and preflight/apply/status/rollback passed, and the catalog parsed/compiled using Babel; the physical-host installation and operator confirmation are now available (details below). This archive is delivered separately, **not promoted into repository restore manifests or RPM packaging**. 

Installation guard: `rpm -q --qf '%{VERSION}' krema` must be `0.13.0`; compile with `msgfmt --check --check-format`, deploy only to `$HOME/.local/share/locale/pl/LC_MESSAGES/krema.mo`. If a catalog exists, make an exact rollback backup. No automatic dock restart, no launcher rewrites or `kremarc` edits.

## Operator installation result and status

The installed catalog resides under the user data tree: `$HOME/.local/share/locale/pl/LC_MESSAGES/krema.mo`. The installer used `$HOME/.local/share/krema-pl/finalization/v01` as its rollback/state directory. The local first-install condition (`EXISTING_CATALOG=False`) is recorded for recovery. Reuse the version-pinned archive rollback procedure after reviewing current catalog hashes; do not remove or overwrite system Krema files. The source release tag remains `v0.13.0`; re-audit after upstream updates.

## Status and exclusions

- Existing Krema/Finder task grouping is accepted: dock pin `org.brhett.finder.desktop`, directory handler `finder-kde-lab-v19.desktop`. Localization must not change either binding.
- **2026-11-16 operator validation:** preflight showed `KREMA_RPM_VERSION=0.13.0`, `PL_TRANSLATION_ENTRIES=268`, source PO SHA-256 `6dd257f6cc29ef6afdf563e46e3f7287649a45a932151d1cfb42d64129277df6`, `EXISTING_CATALOG=False` and `PASS_READ_ONLY_PREFLIGHT`. Applying the package reported `PL_TRANSLATION_CATALOG=INSTALLED`, `PASS_APPLIED_CATALOG_ONLY`, no RPM/config edits and no forced dock restart. Subsequent `--status` returned `STATE=APPLIED_HASH_OK` and `PASS_CATALOG_INTEGRITY`. The operator explicitly confirmed: **the dock UI is in Polish and works**. Acceptance is bounded by this report; every menu/setting/accessibility/plural form was not separately screenshot-reviewed.
- This is a **separate** workstream from Finder's already-accepted v0.5 Polish runtime catalog.
- Fedora 45 KDE clean-room restore and system-wide reproducible localization remain **HOLD**.
