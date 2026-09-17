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

Dhruva remains the largest case: 393 gettext messages, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

## 2026-09-17 extension refresh

Seven new extensions were accepted after physical-host compatibility testing. Their Polish localization status was reviewed separately from runtime compatibility.

| Extension | Upstream Polish support | Repository work required now |
| --- | --- | --- |
| ArcMenu | Yes; Polish is an upstream-maintained language and `pl.po` was recently updated | No translation from scratch; visual/completeness check only |
| Bluetooth Battery Meter | Yes; upstream `po/pl.po` is current and was revised in September 2026 | No custom translation currently planned |
| Caffeine | Yes; upstream ships `locale/pl.po` | No custom translation currently planned |
| Freon | Yes; upstream ships a Polish `locale/pl/LC_MESSAGES` catalog | No custom translation currently planned |
| GSConnect | Yes; v72 had 11 untranslated entries and a Shell gettext-domain integration issue | **Completed and validated on the physical Fedora 44 / GNOME 50.4 host** |
| Tiling Shell | Yes; exact installed v76 / 17.3 catalog audit found 15 untranslated entries and 0 fuzzy entries | **Completion overlay prepared; physical-host validation pending** |
| User Themes | Uses the GNOME `gnome-shell-extensions` localization path, which includes Polish for the GNOME 50 branch | No separate repository translation currently planned |

## GSConnect v72 result

The exact v72 Polish catalog audit found **11 untranslated entries and 0 fuzzy entries**. The repository carries a minimal completion overlay rather than a duplicate full upstream catalog. The installer merges that overlay with the original upstream Polish catalog and preserves a backup.

Runtime testing exposed an additional integration problem: GSConnect v72 ships the Polish catalog as `org.gnome.Shell.Extensions.GSConnect.mo`, but its extension metadata omits `gettext-domain`. GNOME Shell 50 therefore falls back to the extension UUID as the translation domain for Quick Settings, leaving strings such as `Sync between your devices` and `Mobile Settings` in English even though the same catalog works in GSConnect preferences.

The repository installer now sets:

```json
"gettext-domain": "org.gnome.Shell.Extensions.GSConnect"
```

After reloading the GNOME session, the Quick Settings strings were confirmed translated on the physical workstation. The dedicated verifier checks both the merged Polish catalog and the metadata gettext domain.

## Tiling Shell v76 / 17.3 audit

The exact installed extension reports numeric version **76**, version name **17.3**, gettext domain `tilingshell`, and support for GNOME Shell 45 through 50.

The upstream Polish 17.3 catalog audit found **15 untranslated entries and 0 fuzzy entries**. The missing strings cover:

- moving a window to the best tile;
- dynamic border-radius adaptation;
- Snap Assistant layout synchronization;
- raising tiled windows together;
- screen-edge window suggestions;
- the Default, Adaptive, and Granular edge-tiling modes and their descriptions.

The repository now carries a minimal `localization/tiling-shell/pl.po` completion overlay. `scripts/install-tiling-shell-localization.sh` preserves the upstream Polish catalog, merges only the missing entries, and refuses to apply the overlay if the installed Tiling Shell version changes from the audited 17.3 / 76 baseline. `scripts/verify-tiling-shell-localization.sh` reconstructs the expected merged catalog and requires zero untranslated and zero fuzzy entries.

Physical-host installation and UI validation are still required before this completion is marked accepted.

## Result

For the seven newly accepted extensions:

- **0** require a Polish translation from scratch;
- **1** target is completed and physically validated: **GSConnect v72**;
- **1** target has a prepared completion awaiting physical validation: **Tiling Shell v76 / 17.3**;
- **5** already have upstream Polish support and do not currently justify a repository-maintained duplicate translation.

## Evidence from upstream catalogs

The GSConnect Polish catalog is active and maintained, but v72 contained 11 untranslated entries. Its Shell-side localization also required the metadata gettext-domain correction described above.

The Tiling Shell 17.3 Polish catalog is present and compiled upstream. The exact catalog used by the physical workstation contained 15 empty translations and no fuzzy entries.

Bluetooth Battery Meter has a Polish catalog revised on 2026-09-15. Caffeine ships a Polish source catalog, Freon ships a Polish compiled locale, ArcMenu lists Polish among its maintained translations, and User Themes belongs to the GNOME Shell Extensions localization stream.

## Next step

Install the Tiling Shell completion on the physical Fedora 44 / GNOME 50.4 workstation, run the dedicated verifier, visually confirm the affected preferences/menu strings, and then promote the result to accepted status. After that, run the full repository verification to ensure the localization change introduces no regression.
