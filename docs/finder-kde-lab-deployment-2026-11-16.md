# Finder KDE LAB v1.9 — Fedora 45 operator deployment (2026-11-16)

> **Evidence type:** operator-reported shell output, screenshots and GUI checks on the physical Fedora 45 / KDE Plasma 6.8.2 Wayland workstation. This is an **application-level acceptance**, not a fresh full-system verifier, clean-room deployment, or promotion of the Fedora 45/KDE reproducible baseline.
> **Project policy:** stop additional Finder visual customization; retain the separate LAB build and preserve the stock Dolphin package as a fallback.

## Accepted runtime

- Source and runtime remain local to the isolated Finder KDE LAB; the independent executable is launched through the user's `finder-kde-v19` wrapper. The system Dolphin executable and RPM were **not replaced**.
- Polish localization v0.5 was visually accepted by the operator, including sidebar headings, list columns, sorting menu and status bar. Earlier `100% PO` completion represented only populated catalog entries and did **not** establish runtime coverage.
- The initial English UI despite translated `dolphin.po` was caused by missing visibility of the LAB locale directory. Starting Finder with the LAB `profile/data` directory at the front of `XDG_DATA_DIRS` made Polish labels appear. The user subsequently reported the v0.5 launcher/corrected locale behavior working without a manual environment prefix.
- Source domain: `dolphin`; two local catalog locations: `build/locale/pl/LC_MESSAGES/dolphin.mo` and `profile/data/locale/pl/LC_MESSAGES/dolphin.mo`. The v0.4 read-only audit reported 6 already-correct entries, 8 preserved Polish entries, 0 new PO edits, and existing MO catalogs. The later screenshot and operator validation are decisive for the effective runtime language.

## Functional acceptance and scope

| Check | Operator evidence |
| --- | --- |
| Create/open directories, copy, move and rename | **PASS (bounded manual test)** |
| Trash and restore | **PASS (bounded manual test)** |
| Search: `Ctrl+F` opens/closes | **PASS (bounded manual test)** |
| Properties, folder opening, closing windows | **PASS (bounded manual test)** |
| Polish UI after v0.5 | **PASS (visual/operator)** |
| `gio open` and `xdg-open` folder dispatch | **PASS (operator)** |
| `gio mime inode/directory` default | `finder-kde-lab-v19.desktop` |
| `xdg-mime query default inode/directory` | Disagreed earlier (Dolphin); `xdg-mime` emitted missing `qtpaths`; **do not treat this query as the sole oracle** |
| Finder task grouping in Krema | **PASS (operator)** |
| Meta+E | **PASS — operator confirmation (2026-11-16):** shortcut now opens Finder, rather than Dolphin |
| Portal identity and relogin/long-running soak | **OPEN** |

## Integration incident and successful remedy

1. The user-local `finder-kde-lab-v19.desktop` was updated to include `MimeType=inode/directory;` and passed `desktop-file-validate`.
2. The v0.1 and v0.2 guarded default-manager pilots did **not** pass verification and restored the Dolphin preference. They are **not accepted rerun steps**.
3. The Finder was initially absent from the `gio mime` registered applications. `update-desktop-database "$HOME/.local/share/applications"` regenerated `mimeinfo.cache`. Afterwards `gio mime` listed Finder as eligible and recommended.
4. `xdg-mime default finder-kde-lab-v19.desktop inode/directory` emitted `/usr/bin/xdg-mime: ... qtpaths: command not found`, while GIO reported Finder as the default. The host has `/usr/bin/qtpaths6`; the old `qtpaths` name is missing. Avoid installing legacy Qt or creating global workarounds solely to suppress the warning.
5. Both `gio open "$HOME/Dokumenty"` and `xdg-open "$HOME/Dokumenty"` opened the LAB Finder.
6. Krema initially pinned `applications:finder-kde-lab-v19.desktop` while the Finder's `KAboutData` desktop ID is `org.brhett.finder` (`source/src/main.cpp`). This caused a separate pinned icon and running task. Copying the existing validated launcher to user-local `org.brhett.finder.desktop`, refreshing the desktop cache, unpinning the old ID and pinning the matching ID resolved dock task grouping.
7. Operator-reported final Krema entry: `applications:org.brhett.finder.desktop`. GIO still reports `finder-kde-lab-v19.desktop` as the default directory handler. **Two aliases serve different purposes; do not remove the MIME handler merely to deduplicate the launcher.**

## Recheck commands (user scope)

```bash
gio mime inode/directory | head -n 2
grep -o 'applications:[^,]*finder[^,]*' "$HOME/.config/kremarc"
desktop-file-validate "$HOME/.local/share/applications/finder-kde-lab-v19.desktop"
desktop-file-validate "$HOME/.local/share/applications/org.brhett.finder.desktop"
gio open "$HOME/Dokumenty"
xdg-open "$HOME/Dokumenty"
```

Expected user-level relationship: GIO default `finder-kde-lab-v19.desktop`; Krema pinned ID `org.brhett.finder.desktop`. `Meta+E` was separately confirmed by the operator; do not infer portal registration or every third-party file picker from these MIME results.

## Recovery and safety

- **Quick fallback** (only if needed): `gio mime inode/directory org.kde.dolphin.desktop`, then verify `gio mime inode/directory`. A second mechanism is `xdg-mime default org.kde.dolphin.desktop inode/directory`, but this host's `xdg-mime`/Qt-path failure must be checked, not ignored.
- A pre-change `mimeapps.list` backup and `mimeinfo.cache.before` snapshot were made under the user's Finder finalization directory. The versioned pilot scripts also saved rollback metadata; **do not rerun failed v0.1/v0.2 apply or rollback blindly after later manual MIME changes**.
- Pinning recovery: remove `applications:org.brhett.finder.desktop` in the Krema GUI and re-pin a desired application; do not overwrite the entire `PinnedLaunchers` list.
- No `sudo`, system Dolphin removal or package-file patch is required for the accepted setup.
- Preserve local source modifications and backup state; the repository has not imported the local LAB executable, user profiles or system configuration.
- The session emitted a non-fatal portal warning: `Could not register app ID: App info not found for 'org.brhett.finder'`. Follow up separately if portal-dependent functionality fails. Functional open tests still passed.

**Decision:** `FINDER_V19_PHYSICAL_APP_ACCEPTANCE=PASS_BOUNDED`; `FINDER_USER_MIME_GIO=PASS`; `FINDER_KREMA_TASK_GROUPING=PASS`; `FEDORA45_KDE_CLEAN_ROOM_RESTORE=HOLD`. Historical A6588.1 dialog ownership review is still unresolved; this bounded acceptance does not retroactively mark it PASS.
