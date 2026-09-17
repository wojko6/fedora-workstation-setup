# Polish localization status

This document tracks Polish localization coverage for GNOME Shell extensions in the accepted Fedora 44 / GNOME 50.4 workstation baseline.

The repository carries its own localization only when upstream Polish support is missing, incomplete for the tested version, or user-visible strings are not exposed through an upstream Polish gettext catalog. Existing upstream translations remain attributed to their original projects and translators.

## Repository-managed localization already accepted

The existing localization work covers the established extension/integration targets through gettext sources, source patches, or controlled runtime patches:

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

Dhruva remains the largest accepted case: 393 gettext messages, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

## 2026-09-17 extension refresh

Seven new extensions were accepted after physical-host compatibility testing. Their Polish localization status was reviewed separately from runtime compatibility.

| Extension | Upstream Polish support | Repository work required now |
| --- | --- | --- |
| ArcMenu | Yes; Polish is an upstream-maintained language and `pl.po` was recently updated | No translation from scratch; visual/completeness check only |
| Bluetooth Battery Meter | Yes; upstream `po/pl.po` is current and was revised in September 2026 | No custom translation currently planned |
| Caffeine | Yes; upstream ships `locale/pl.po` | No custom translation currently planned |
| Freon | Yes; upstream ships a Polish `locale/pl/LC_MESSAGES` catalog | No custom translation currently planned |
| GSConnect | Yes; v72 had 11 untranslated entries and a Shell gettext-domain integration issue | **Completed and validated on the physical Fedora 44 / GNOME 50.4 host** |
| Tiling Shell | Yes; exact installed v76 / 17.3 catalog audit found 15 untranslated entries and 0 fuzzy entries | **Completed and validated on the physical Fedora 44 / GNOME 50.4 host** |
| User Themes | Uses the GNOME `gnome-shell-extensions` localization path, which includes Polish for the GNOME 50 branch | No separate repository translation currently planned |

## GSConnect v72 result

The exact v72 Polish catalog audit found **11 untranslated entries and 0 fuzzy entries**. The repository carries a minimal completion overlay rather than a duplicate full upstream catalog. The installer merges that overlay with the original upstream Polish catalog and preserves a backup.

Runtime testing exposed an additional integration problem: GSConnect v72 ships the Polish catalog as `org.gnome.Shell.Extensions.GSConnect.mo`, but its extension metadata omits `gettext-domain`. GNOME Shell 50 therefore falls back to the extension UUID as the translation domain for Quick Settings, leaving strings such as `Sync between your devices` and `Mobile Settings` in English even though the same catalog works in GSConnect preferences.

The repository installer now sets:

```json
"gettext-domain": "org.gnome.Shell.Extensions.GSConnect"
```

After reloading the GNOME session, the Quick Settings strings were confirmed translated on the physical workstation. The dedicated verifier checks both the merged Polish catalog and the metadata gettext domain.

## Tiling Shell v76 / 17.3 result

The exact installed extension reports numeric version **76**, version name **17.3**, gettext domain `tilingshell`, and support for GNOME Shell 45 through 50.

The upstream Polish 17.3 catalog audit found **15 untranslated entries and 0 fuzzy entries**. The missing strings covered:

- moving a window to the best tile;
- dynamic border-radius adaptation;
- Snap Assistant layout synchronization;
- raising tiled windows together;
- screen-edge window suggestions;
- the Default, Adaptive, and Granular edge-tiling modes and their descriptions.

The repository carries a minimal `localization/tiling-shell/pl.po` completion overlay. `scripts/install-tiling-shell-localization.sh` preserves the upstream Polish catalog, merges only the missing entries, and refuses to apply the overlay if the installed Tiling Shell version changes from the audited 17.3 / 76 baseline. `scripts/verify-tiling-shell-localization.sh` reconstructs the expected merged catalog and requires zero untranslated and zero fuzzy entries.

The completion installer and dedicated verifier both passed on the physical Fedora 44 / GNOME 50.4 workstation, and the affected preferences were visually checked after installation. The Tiling Shell completion is therefore accepted for the tested 17.3 / 76 baseline.

## Just Perfection v37 result

The installed physical-host extension reports **Just Perfection v37**, gettext domain `just-perfection`, and GNOME Shell 50 compatibility.

Upstream does not ship a Polish catalog for this baseline, so the repository now carries a full `localization/just-perfection/pl.po` translation plus a small `v37-additions.po` completion catalog for strings that are present in the actual v37 UI but absent from the stale upstream `po/main.pot` template. Physical visual testing exposed this template drift through untranslated Backlight and Do Not Disturb controls; the missing v37 strings were then added explicitly.

`scripts/install-just-perfection-localization.sh` is pinned to v37, compiles and installs the merged Polish catalog, and refuses to apply it after an extension-version change until the translation is re-audited. `scripts/verify-just-perfection-localization.sh` checks the installed version, gettext domain, repository catalog completeness, the required v37 completion strings, and the installed `.mo` artifact.

The translation was installed on the physical Fedora 44 / GNOME 50.4 workstation and visually checked in the Just Perfection preferences UI. The previously English Backlight and Do Not Disturb rows are now translated, so **Just Perfection v37 is accepted for the tested baseline**. The restore localization stage now invokes its dedicated installer automatically.

## Result

For the seven extensions from the 2026-09-17 compatibility refresh:

- **0** required a Polish translation from scratch;
- **2** confirmed completion targets are completed and physically validated: **GSConnect v72** and **Tiling Shell v76 / 17.3**;
- **5** already have upstream Polish support and do not currently justify a repository-maintained duplicate translation.

The separate follow-up localization pass for older accepted extensions has now completed its first from-scratch target: **Just Perfection v37**.

The latest full physical-host repository verifier result recorded before adding the dedicated Just Perfection check remains:

```text
PASS=221 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

That aggregate number should only be updated after the Just Perfection verifier is integrated into `scripts/verify.sh` and the full physical verifier is run again.

## Evidence from upstream catalogs

The GSConnect Polish catalog is active and maintained, but v72 contained 11 untranslated entries. Its Shell-side localization also required the metadata gettext-domain correction described above.

The Tiling Shell 17.3 Polish catalog is present and compiled upstream. The exact catalog used by the physical workstation contained 15 empty translations and no fuzzy entries before the repository completion overlay was applied.

Bluetooth Battery Meter has a Polish catalog revised on 2026-09-15. Caffeine ships a Polish source catalog, Freon ships a Polish compiled locale, ArcMenu lists Polish among its maintained translations, and User Themes belongs to the GNOME Shell Extensions localization stream.

Just Perfection v37 declares gettext domain `just-perfection` but its upstream Polish catalog is absent. Its upstream POT is also stale relative to the actual v37 preferences UI, so the repository keeps the main full translation and the audited v37-only completion strings separately reviewable.

## Maintenance and active localization work

The 2026-09-17 seven-extension localization refresh is closed and remains in maintenance mode. The follow-up pass for accepted extensions that still lack Polish coverage remains active after completing Just Perfection v37. Upstream Polish coverage must be re-audited whenever an accepted extension version changes, and repository-managed translations remain limited to demonstrated gaps or absent upstream catalogs.
