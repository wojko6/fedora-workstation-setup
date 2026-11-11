# KDE Plasma AppBay + Krema native Launchpad — 2026-11-11

> **Environment (operator-reported):** physical Fedora 45, KDE Plasma 6.8.2, Wayland, external 2560×1440@180 Hz display and Krema 0.13.0.
> **Scope:** bounded operator-verified desktop UI integration, not a reproducible Fedora 45/KDE desired-state promotion or clean-room restore test.
> **Source:** [Plasma-AppBay](https://github.com/zayronxio/Plasma-AppBay). No upstream patch or package modification is claimed.

## Intended behavior and observed acceptance

An existing Krema launcher opens the **native AppBay plasmoid hosted by `plasmashell`**, rather than a second `plasmawindowed` application. The native view shows the applications grid, supports searching and page navigation, and closes with `Esc`. The user disabled AppBay's own **Enabled Favorites dock** option and selected a transparent compact-button image in the top panel to avoid the additional visible Apple-style widget button. The widget itself **must remain installed on that panel** for the Krema activation to work.

Operator-supplied screen captures and terminal outputs confirm the end-to-end Krema click → native applications grid → `Esc` flow and repeat opening. A KDE refresh log reported:

```text
APPBAY_REFRESH_V2 root=13 source=154 grid=154
```

This is evidence of **154 grid model entries at that checkpoint**, not a universal application count or a measured animation frame rate. The external monitor was configured at 180 Hz, but no definitive AppBay display-FPS measurement was made.

## Failure analysis and successful remedy

1. **Standalone host window:** `plasmawindowed Plasma.AppBay` initially displayed a compact Apple-logo window; clicking it opened the grid. An experimental auto-open QML change eliminated the extra click, but the compact host window remained.
2. **Rendering experiments:** default `threaded` looked choppy to the operator; `QSG_RENDER_LOOP=basic` felt more consistent in `plasmawindowed`. `threaded` with `QSG_USE_SIMPLE_ANIMATION_DRIVER=1` initially seemed smooth but was not repeatable. These settings applied only to the standalone process; they do **not** imply any special rendering mode in native `plasmashell`.
3. **Failed host-window workarounds:** combining `--statusnotifier`, host-window hiding and process quit caused a hidden/stale `plasmawindowed` instance; KWin opacity experiments were also not adopted. Terminating only the identified stale AppBay process restored standalone operation. Neither workaround belongs in the accepted setup.
4. **Native grid initially empty:** the native widget showed the blurred overlay and search field, while typing a query produced matches; clearing the query removed the icons again. This distinguished the working search model from the initially empty all-apps grid. The QML journal included `AppList.qml:27: Cannot read property 'count' of null` and a `JSON.parse` error.
5. **Local QML guard:** a bounded `try/catch` around `JSON.parse(appBaySettings.value("configSubModelJson"))` falls back to an empty group array. This guards malformed stored data but **was not sufficient alone** to populate the native grid.
6. **Refresh-event fix:** local `main.qml` handles the `Kicker.RootModel` **`onRefreshed`** signal, schedules `generateModel()` via `Qt.callLater` and emits a bounded `APPBAY_REFRESH_V2` diagnostic containing root/source/grid counts. The earlier retry timers were removed. After a controlled `plasma-plasmashell.service` restart, the operator observed `root=13 source=154 grid=154` twice, followed by a visible full grid. This is a local compatibility fix, **not a verified upstream change**.

The observed errors in `AppList.qml` may still occur briefly during initialization; the successful screen test does not establish a clean warning-free QML runtime.

## Native activation from Krema

The working native AppBay panel instance was **applet ID 100** on the operator's host. A global widget action was registered by assigning a keyboard shortcut to that widget. Once registered, the following D-Bus call successfully activated the native grid:

```bash
gdbus call --session \
  --dest org.kde.kglobalaccel \
  --object-path /component/plasmashell \
  --method org.kde.kglobalaccel.Component.invokeShortcut \
  "activate widget 100"
```

The existing user launcher `appbay-basic.desktop`, already pinned in Krema, was changed to execute the same `gdbus` call instead of launching `plasmawindowed`. Its filename is historical; it does **not** indicate that native `plasmashell` uses the Qt `basic` render loop. A successful D-Bus response `()` alone is insufficient; the operator also visually confirmed the native grid opened.

**Important lifecycle constraint:** the numeric ID `100` is not portable or stable across removing/readding the applet or rebuilding panel configuration. A restored installation must discover the new applet ID, register a widget activation shortcut and update the launcher. **Do not remove the hidden compact widget** simply because its icon is invisible; the dock relies on it.

## Operator-only recovery / verification guidance

- Preserve local copies of the original user AppBay QML and configuration before changing them. The operator reported a separate final configuration backup, but these backup bytes and hashes are **not included in Git** and were not independently verified by repository CI.
- Verify the native applet is still present in the Plasma panel configuration and its activation action is registered in `kglobalshortcutsrc`; use the actual current widget ID rather than copying `100` unconditionally.
- Test native opening from the applet itself first, then `gdbus` activation, then the Krema launcher, and finally `Esc` and a second opening.
- If the all-apps grid is blank but search results appear, check the current AppBay source, QML journal and model refresh signaling before adding timers or resetting settings. The successful local fix relied on `onRefreshed` and a `plasmashell` reload.
- Do not use KWin opacity tricks, generic `pkill plasmawindowed`, global `QSG_RENDER_LOOP` exports, automatic `--statusnotifier` or undocumented host-window hiding as restore steps.
- The user-level transparent image and disabled **Favorites dock** are presentation preferences, not part of the accepted GNOME desired-state installer. Treat local applet version, QML APIs and KDE D-Bus shortcut behavior as requiring revalidation after updates.

## Acceptance boundary

| Check | Observed result |
| --- | --- |
| Native app list after model refresh | **PASS — operator UI and journal** |
| Search, page navigation and `Esc` | **PASS — operator UI** |
| Native activation by D-Bus | **PASS — operator UI** |
| Native activation from existing Krema icon | **PASS — operator UI** |
| No extra `plasmawindowed` Apple-logo window in accepted path | **PASS — operator UI** |
| Measured 180 FPS, long-run/relogin/reboot regression | **NOT TESTED** |
| Automatic clean-room restore of KDE applet + Krema | **HOLD** |

**Decision:** `APPBAY_KREMA_NATIVE_UI=PASS_BOUNDED`; `FEDORA45_KDE_REPRODUCIBLE_BASELINE=HOLD`. This documentation does not modify the workstation, the live dock, any RPM, or the accepted historical Fedora 44/GNOME baseline.

## Related documents

- [2026-11-11 worklog](WORKLOG-2026-11-11.md)
- [2026-11-10 physical Fedora 45 migration](WORKLOG-2026-11-10.md)
- [Documentation index](README.md)
