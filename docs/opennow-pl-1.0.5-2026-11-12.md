# OpenNOW 1.0.5 PL — final localized AppImage evidence (2026-11-12)

> **Scope:** Fedora 45 / KDE Plasma 6.8.2 / Wayland, operator-run custom Polish build. This records a local application acceptance, **not** the Fedora clean-room or reproducible restore baseline. No user credentials, private profiles, compiled executables, or backup artifacts are committed to the public repository.

## Source and immutable evidence

| Item | Evidence |
| --- | --- |
| Upstream | [OpenCloudGaming/OpenNOW](https://github.com/OpenCloudGaming/OpenNOW) release `v1.0.5` |
| Pinned upstream commit | `a9de957a5902c54186e9d4b44b1562f0b6beb951` |
| Pristine Git `locales/pl.json` blob | `869594ad9116a062318cac734472653ff473496a` |
| Final custom AppImage SHA-256 | `b060a466c65d08d1af9b5d78156ea02adea0fc0d9d9990d9198d852eb7954958` |
| Previous local PL AppImage SHA-256 | `f6e9332dfad2e11a75048d4fcc88a2ea42d0b31f4f7f2934a8794df5b8ab212c` |
| Final target | `~/Aplikacje/OpenNOW-PL/OpenNOW-Qt-1.0.5-PL-Linux-x64.AppImage` |
| Independent official target | `~/Aplikacje/OpenNOW/OpenNOW-Qt-1.0.5-Linux-x64.AppImage` (unchanged) |

A working Qt/Rust and packaging lab was maintained separately from the installed AppImages. The v4.1 output path under `~/Projekty/OpenNOW-1.0.5-PL-Build-LAB/final-builds/v4-1-20261112T133842Z-pid133810/` is a **host-only evidence path**, not a checked-in binary or a restore recipe.

## Catalog audit and language decisions

- **4,180/4,180** English and Polish keys match; **0 structural errors** were reported.
- Initially **266** entries were identical EN/PL. These cannot be called 266 translation defects: names, codecs, units, shortcuts, placeholders, technical identifiers and some valid Polish words stay unchanged.
- Review of the 266 entries: **240 keep unchanged**, **6 concrete translation proposals**, **19 requiring contextual UI confirmation**, **1 suspected upstream-source/extraction anomaly**. These are text-level review categories, not all verified by live UI.
- The final custom catalog staged **nine changed localization keys** and left **260 English/Polish-identical strings**. This is not a measure of translation accuracy.
- Reviewed changes included a saved-GPU-unavailable warning (restoring English meaning), open-source typography, frame-generation GPU phrasing, automatic-setting labels, a game-account platform list and the `READY` device status.
- The English upstream source also contains `qt.s_3468f189 = "s connected"`; translate only after determining the source/extraction context.

**Language sign-off remains partial.** The 19 contextual items and the upstream string remain open; there is no claim of 100% human language verification.

## FPS selector and code-level fix

The desktop FPS selector originally reused `AUTO` as an internal sentinel and visible label. The safe custom QML change separates `{label, value}` while retaining `AUTO` as the choice value and `fps=0` in settings. The visible label is **Automatycznie**.

The first v3-only proposal could hide the automatic option after selecting a numeric FPS. That candidate was **not compiled for release**. v4 corrected it: Auto is always offered, numeric or otherwise retained FPS choices still work, and selection indices and persistence preserve internal values. The operator subsequently confirmed GUI switching worked.

## Build, packaging and host activation

The operator supplied these v4.1 results:

```text
SELF_TESTS=13/13 PASS
PREFLIGHT=PASS
CLONED_UPSTREAM_PL_BLOB=PASS
REVIEWED_PL_STAGED_IN_ISOLATED_CLONE=YES
QT_BUILD=PASS
CI_UNIT_TESTS=PASS
CMAKE_STAGE=PASS
WAYLAND_SMOKE=PASS
RESULT=PASS_ISOLATED_BUILD_SMOKE_ONLY
```

The previous v4 run stopped safely at `CLONED_BASE_PL_MISMATCH` because it compared the pristine upstream Git checkout with an earlier **modified** Polish catalog hash. v4.1 checked the pinned upstream Git blob before applying the reviewed localized payload in an isolated clone.

Linux AppImage packaging used **patchelf 0.19.1**. An earlier packaging path had corrupted ELF `DT_INIT` initialization metadata in a bundled library, yielding an AppImage startup crash despite successful compilation. The new path passed package checks and a Wayland startup smoke test; this is not a cross-distribution compatibility claim.

The operator tested the isolated GUI and reported working Polish text and **Automatycznie ↔ numeric FPS** behavior. The final hash-gated replacement affected **only** the Polish target and produced:

```text
SOURCE_SHA256=b060a466c65d08d1af9b5d78156ea02adea0fc0d9d9990d9198d852eb7954958
INSTALLED_SHA256=f6e9332dfad2e11a75048d4fcc88a2ea42d0b31f4f7f2934a8794df5b8ab212c
OPENNOW_PL_FINAL=PASS
OFFICIAL_OPENNOW_UNCHANGED=YES
BACKUP_CREATED=NO
RESULT=PASS
TERMINAL_ACTIVE=YES
```

A normal launch from the **existing Krema dock icon** was subsequently confirmed. Final KDE launchers and pins were not modified. No backup was created **by the operator's explicit choice for this app-only replacement**; this does not supersede the broader workstation backup policy.

## Remaining gates and operational notes

- No distinct final **extended streaming** run was recorded in the v4.1 log (`STREAMING_TEST=PENDING` at build time). General UI success does not establish a timed stream regression result.
- A previous installation command placed `set -euo pipefail` directly in an interactive shell; a later failing guard closed the terminal. Using a **child Bash process** resolved this, as confirmed by `TERMINAL_ACTIVE=YES`.
- This separately built app is **not included** in the Fedora repository's GNOME restore/localization installer. Fedora 45/KDE clean-room promotion remains **HOLD**.
- No separate GitHub issue was created for the documentation update.

**Result:** `APPIMAGE_INSTALL=PASS` · `KREMA_LAUNCH=PASS_OPERATOR_CONFIRMED` · `CI_UNIT_TESTS=PASS` · `WAYLAND_SMOKE=PASS` · `LANGUAGE_SIGNOFF=PARTIAL` · `FEDORA45_REPRODUCIBLE_BASELINE=HOLD`.
