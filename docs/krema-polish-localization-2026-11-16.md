# Krema 0.13.0 — Polish localization discovery and safe deployment plan (2026-11-16)

> **Status:** source-reviewed, user-only localization pilot planned; **full Polish runtime acceptance not yet claimed**.
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

## Status and exclusions

- Existing Krema/Finder task grouping is accepted: dock pin `org.brhett.finder.desktop`, directory handler `finder-kde-lab-v19.desktop`. Localization must not change either binding.
- No recorded full-system Polish Krema UI pass yet. Translation deployment must be tested on the physical host.
- This is a **separate** workstream from Finder's already-accepted v0.5 Polish runtime catalog.
- Fedora 45 KDE clean-room restore and system-wide reproducible localization remain **HOLD**.
