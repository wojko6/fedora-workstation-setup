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
| Tiling Shell | Yes, but the current upstream Polish catalog still contains untranslated entries | **Yes — completion/review required** |
| User Themes | Uses the GNOME `gnome-shell-extensions` localization path, which includes Polish for the GNOME 50 branch | No separate repository translation currently planned |

## GSConnect v72 result

The exact v72 Polish catalog audit found **11 untranslated entries and 0 fuzzy entries**. The repository now carries a minimal completion overlay rather than a duplicate full upstream catalog. The installer merges that overlay with the original upstream Polish catalog and preserves a backup.

Runtime testing exposed an additional integration problem: GSConnect v72 ships the Polish catalog as `org.gnome.Shell.Extensions.GSConnect.mo`, but its extension metadata omits `gettext-domain`. GNOME Shell 50 therefore falls back to the extension UUID as the translation domain for Quick Settings, leaving strings such as `Sync between your devices` and `Mobile Settings` in English even though the same catalog works in GSConnect preferences.

The repository installer now sets:

```json
"gettext-domain": "org.gnome.Shell.Extensions.GSConnect"
```

After reloading the GNOME session, the Quick Settings strings were confirmed translated on the physical workstation. The dedicated verifier checks both the merged Polish catalog and the metadata gettext domain.

## Result

For the seven newly accepted extensions:

- **0** require a Polish translation from scratch;
- **1** confirmed target is now completed: **GSConnect v72**;
- **1** confirmed completion target remains: **Tiling Shell v76**;
- **5** already have upstream Polish support and do not currently justify a repository-maintained duplicate translation.

## Evidence from upstream catalogs

The GSConnect Polish catalog is active and maintained, but v72 contained 11 untranslated entries. Its Shell-side localization also required the metadata gettext-domain correction described above.

The Tiling Shell Polish catalog is present and compiled upstream, but contains several empty translations, including strings related to best-tile movement, smart border radius, layout synchronization, raising tiled windows together, and screen-edge window suggestions.

Bluetooth Battery Meter has a Polish catalog revised on 2026-09-15. Caffeine ships a Polish source catalog, Freon ships a Polish compiled locale, ArcMenu lists Polish among its maintained translations, and User Themes belongs to the GNOME Shell Extensions localization stream.

## Next step

Audit the **exact installed Tiling Shell v76** Polish catalog, extract all untranslated and fuzzy user-visible strings, and create the smallest reproducible completion necessary for the tested workstation version. Any new localization must remain reviewable and must pass dedicated verification before acceptance.
