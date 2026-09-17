# Polish localization status

This document tracks Polish localization coverage for GNOME Shell extensions in the accepted Fedora 44 / GNOME 50.4 workstation baseline.

The repository carries its own localization only when upstream Polish support is missing, incomplete for the tested version, or user-visible strings are not exposed through a usable upstream Polish gettext path. Existing upstream translations remain attributed to their original projects and translators.

## Repository-managed localization already accepted

Accepted repository-managed localization/integration targets are:

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
- Spotlight v14 / 2026.11 Polish localization and gettext integration
- Space Bar v39 controlled Polish localization

Dhruva remains the largest accepted case: 393 gettext messages, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

## 2026-09-17 extension refresh

Seven new extensions were accepted after physical-host compatibility testing. Their Polish localization status was reviewed separately from runtime compatibility.

| Extension | Upstream Polish support | Repository work required now |
| --- | --- | --- |
| ArcMenu | Yes; Polish is upstream-maintained | No duplicate repository translation |
| Bluetooth Battery Meter | Yes; upstream Polish catalog is current | No duplicate repository translation |
| Caffeine | Yes; upstream ships Polish | No duplicate repository translation |
| Freon | Yes; upstream ships Polish | No duplicate repository translation |
| GSConnect | Yes; v72 had 11 untranslated entries and a Shell gettext-domain integration issue | **Completed and validated** |
| Tiling Shell | Yes; exact v76 / 17.3 catalog had 15 untranslated entries | **Completed and validated** |
| User Themes | Uses GNOME Shell Extensions localization with Polish support | No separate repository translation |

## GSConnect v72

The exact v72 Polish catalog audit found **11 untranslated entries and 0 fuzzy entries**. The repository carries a minimal completion overlay rather than a duplicate full upstream catalog.

Runtime testing exposed an additional integration problem: GSConnect v72 ships the Polish catalog as `org.gnome.Shell.Extensions.GSConnect.mo`, but its extension metadata omits `gettext-domain`. GNOME Shell 50 therefore used the wrong domain for Shell-side strings. The repository installer sets:

```json
"gettext-domain": "org.gnome.Shell.Extensions.GSConnect"
```

After logout/login, Quick Settings strings were confirmed translated on the physical workstation. The dedicated verifier checks both the merged Polish catalog and metadata domain.

## Tiling Shell v76 / 17.3

The exact installed extension reports numeric version **76**, version name **17.3**, gettext domain `tilingshell`, and GNOME Shell 45–50 support.

The upstream Polish 17.3 catalog audit found **15 untranslated entries and 0 fuzzy entries**. The repository carries a minimal `localization/tiling-shell/pl.po` completion overlay pinned to this tested version. The installer preserves the upstream catalog, merges only the missing entries, and refuses to apply the overlay after version drift. The dedicated verifier requires zero untranslated and zero fuzzy entries.

The completion installer and verifier both passed on the physical Fedora 44 / GNOME 50.4 workstation, and the affected preferences were visually checked.

## Just Perfection v37

The installed physical-host extension reports **Just Perfection v37** and gettext domain `just-perfection`.

Upstream does not provide complete Polish coverage for this baseline. The repository carries `localization/just-perfection/pl.po` plus a small `v37-additions.po` for strings present in the actual v37 UI but absent from the stale upstream template.

`scripts/install-just-perfection-localization.sh` is pinned to v37 and installs the merged catalog. `scripts/verify-just-perfection-localization.sh` checks the installed version, gettext domain, repository catalog completeness, required v37-only strings, and installed `.mo` artifact.

The translation was installed and visually checked on the physical Fedora 44 / GNOME 50.4 workstation. Just Perfection v37 is accepted for the tested baseline.

## Spotlight v14 / 2026.11

The physical workstation reports **Spotlight v14**, version name **2026.11**. The audited upstream source does not provide a locale tree, Polish catalog, or `gettext-domain`; preferences strings are embedded directly in source.

The repository therefore carries a controlled exact-version localization. `localization/spotlight/pl.po` contains the audited Polish strings, four source patches expose the preferences UI through gettext, and `scripts/install-spotlight-localization.sh` adds `"gettext-domain": "spotlight"`, compiles `spotlight.mo`, and keeps a version-specific pristine backup.

`scripts/verify-spotlight-localization.sh` reconstructs the expected patched source, validates the gettext domain and installed catalog, and requires **22 translated entries**.

After logout/login, the preferences UI was visually checked and confirmed translated. Spotlight v14 / 2026.11 is accepted for the tested baseline.

## Space Bar v39

The physical workstation reports **Space Bar v39** (`space-bar@luchrioh`). The audited upstream v39 release supports GNOME 50 but does not provide a gettext catalog/localization tree for the user-visible strings audited in this project.

Because the release has no usable upstream localization path, the repository uses a controlled exact-version source replacement strategy rather than pretending an upstream gettext implementation exists. The localization is pinned to the audited v39 package fingerprints and covers six installed JavaScript files:

- `preferences/BehaviorPage.js`
- `preferences/AppearancePage.js`
- `preferences/ShortcutsPage.js`
- `preferences/common.js`
- `preferences/custom-styles.js`
- `ui/WorkspacesBarMenu.js`

The accepted mapping contains **109 translated source patterns** covering the Behavior, Appearance, and Shortcuts preferences, keyboard-shortcut dialogs, Custom Styles UI, and the runtime panel menu.

`scripts/install-space-bar-localization.sh` validates the exact v39 metadata/file fingerprints, creates a version-specific pristine backup, refuses to overwrite unknown same-version builds, applies the repository mapping, and verifies the installed result.

`scripts/verify-space-bar-localization.sh` rebuilds the expected localized files from the pristine backup and compares every managed file byte-for-byte with the live extension. The dedicated verifier returned:

```text
Translated patterns: 109
PASS: Space Bar v39 Polish localization matches repository
VERIFY_RC=0
```

The translated UI was also confirmed working on the physical Fedora 44 / GNOME 50.4 workstation. **Space Bar v39 is accepted for the tested baseline.** Its installer is part of `scripts/install-localizations.sh`, and its dedicated verifier is integrated into the main `scripts/verify.sh`.

## Current physical-host result

After Space Bar v39 was integrated into the main verifier and NordVPN/gNordVPN-Local were removed from desired state, the full physical-host verification completed with:

```text
PASS=218 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the current accepted aggregate. The lower absolute PASS count compared with older documentation is expected because NordVPN-related desired-state checks were removed; the accepted result is defined by zero warnings and zero failures for the current desired state, not by preserving an obsolete absolute check count.

## Maintenance policy

Repository-managed translations are version-scoped. Whenever an accepted extension version changes, upstream Polish coverage and source layout must be re-audited before the repository overlay is considered valid for the new release.

Where upstream already provides complete Polish support, this repository should not carry a redundant duplicate translation. Where upstream support is incomplete, the repository should prefer minimal completion overlays. Where no localization mechanism exists, controlled exact-version source localization may be used only with strict fingerprinting, backups, deterministic verification, and physical UI validation.
