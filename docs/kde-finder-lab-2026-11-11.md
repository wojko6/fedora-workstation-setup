# Fedora 45 — Finder KDE LAB v0.1 (2026-11-11)

> Evidence boundary: physical-workstation console outputs copied by the operator; upstream source review through the GitHub repository. No assistant execution on the workstation, no independent runtime screenshot or binary reproducibility test.
> Scope: a **separate experimental KDE Dolphin fork**, not a replacement of the system file manager. This document does not promote the Fedora 45/KDE clean-room restore baseline.

## Source and rationale

- Source: [jingledingle521/finder-kde](https://github.com/jingledingle521/finder-kde), pinned commit `1e02adccdb85f18d0a080b3a7383c13916176237` (2026-11-02). The operator checked the local checkout's `git rev-parse HEAD` against this exact SHA.
- Fork base: Dolphin **26.08.1**; system-installed Dolphin is **26.08.2-3.fc45**. Finder provides its own application identity and `finderrc` configuration, as advertised upstream.
- Interest: Finder-like chrome, sidebar, column view, list styling and Tahoe integration. Optional AirDrop, cloud mounts and xdg-desktop-portal file chooser integration are **out of scope** for the first lab.
- For comparison, [marcosfantonio/dolphin-finder-tahoe](https://github.com/marcosfantonio/dolphin-finder-tahoe) is a narrower visual fork based on Dolphin 26.08.2, primarily targeting CachyOS/Arch.

## Recorded host-side checkpoints

| Check | Operator evidence | Outcome |
| --- | --- | --- |
| OS and toolchain | Fedora 45; GCC 16.2.1, CMake, Ninja, Git and pkg-config present | `ENV=PASS` |
| Qt/KF6 | Qt development package 6.11.2, ECM/KF6 development components 6.31.0 | `CMAKE_DEPENDENCIES=PASS` after dependency resolution |
| Initial configure | Missing `KF6NewStuff`, `KF6DBusAddons`, `KF6Parts`, `KF6TextWidgets`; initial `kf6-kfilemetadata-devel` absent | `CMAKE_INITIAL=BLOCKED_DEPS` |
| DNF dry run | Five requested KF6 `-devel` packages plus Attica/Sonnet `-devel`; **7 installations, 0 removals, no upgrades**, approximately 2 MiB installed size | `DNF_PLAN=PASS_NOT_APPLIED_BY_DRY_RUN` |
| Repository warning | COPR `tgerov/vpcs` Fedora 45 metadata returned HTTP 404; this is unrelated to Finder's source | `REPO_WARNING=NON_BLOCKING` |
| Repeat configure | All required KDE Frameworks 6.31.0 components found; CMake reported `Configuring done` / `Generating done` | `CMAKE=PASS` |
| Build | Operator ran the CMake/Ninja build with parallelism 2 and reported `BUILD_RC=0` | `BUILD=PASS_OPERATOR_REPORTED` |
| Binary/runtime linkage | `build/bin/finder`, `libdolphinprivate.so.6`, `libdolphinvcs.so.6` located in the lab build tree; filtered `ldd` output showed both private libraries resolving from the lab, no displayed `not found` entry | `BINARY_LINKAGE=PASS_BOUNDED` |
| Default handler | `xdg-mime query default inode/directory` returned `org.kde.dolphin.desktop` | `STOCK_DOLPHIN_DEFAULT=UNCHANGED` |

The repeat CMake configuration used `-DBUILD_TESTING=OFF`, `-DFINDER_BUNDLE_RCLONE=OFF`, `-DKDE_INSTALL_USE_QT_SYS_PATHS=OFF`, and a **user-local lab staging prefix**. Optional `KF6UserFeedback`, `KF6DocTools`, `PackageKitQt6`, `KF6Baloo` and `KF6BalooWidgets` were not found. Missing Baloo components can restrict metadata and information-panel functionality; they did not prevent this build. No bundled rclone or AirDrop build was requested.

## Important installer boundary

Upstream `finder-extras/install.sh` **was not executed**. Although it installs the app under the user home, it additionally changes the user `xdg-desktop-portal` file chooser preference, registers a D-Bus service, attempts to install a system portal descriptor through `pkexec`, and restarts a user portal service. Separately, the project CMake installation rules include Dolphin-named desktop entries, KCMs, plugins and migration files. Therefore, **do not run unreviewed `cmake --install` into system directories**, and do not expose a broad lab prefix through global `XDG_DATA_DIRS` or `QT_PLUGIN_PATH` without checking collisions.

Upstream `finder-extras/install-airdrop` was not run; it can install additional dependencies and alter firewalld. The user did not authorize any Finder cloud login, default-file-manager switch, or portal replacement.

## Next bounded lab step — not yet validated

1. Check built file paths and runtime library resolution; prepare an isolated XDG config/data/cache/state profile.
2. Launch `build/bin/finder --new-window` against an **empty test directory**, with an ordinary unprivileged user; observe terminal diagnostics and GUI appearance.
3. Verify Polish UI, Tahoe window controls, icon/list/Miller column views, and close behavior.
4. Only after separate confirmation, consider selective user-local staging/launcher integration. Do **not** promote to default file manager.

The operator reported an **attachment-upload error** preventing a screenshot in this conversation. This is not evidence that Finder started, nor evidence of a Finder runtime failure. The actual GUI launch and screenshot remain **NOT_REPORTED**.

**Decision:** `FINDER_KDE_SOURCE=PASS_PINNED`; `FINDER_KDE_CMAKE=PASS`; `FINDER_KDE_BUILD=PASS_OPERATOR`; `FINDER_KDE_LINKAGE=PASS_BOUNDED`; `FINDER_KDE_GUI=NOT_REPORTED`; `FINDER_KDE_SYSTEM_INSTALL=NO`; `FEDORA45_KDE_REPRODUCIBLE_RESTORE=HOLD`.

## Related records

- [November 11 worklog](WORKLOG-2026-11-11.md)
- [MacTahoe SDDM / lock-screen visual state](kde-mactahoe-sddm-2026-11-11.md)
- [Project status](../PROJECT-STATUS.md)
