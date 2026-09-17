# Polish localization status

This document tracks Polish localization coverage for GNOME Shell extensions in the accepted Fedora 44 / GNOME 50.4 workstation baseline.

The repository carries its own localization only when upstream Polish support is missing, incomplete for the tested version, or user-visible strings are not exposed through an upstream Polish gettext catalog. Existing upstream translations remain attributed to their original projects and translators.

## Repository-managed localization already accepted

The existing localization work covers eight extension/integration targets through gettext sources, source patches, or controlled runtime patches:

- Desktop Icons NG (DING)
- Brightness control using ddcutil
- Just Another Search Bar
- Monitor Smart Saver
- Dhruva
- Background Logo
- Browser Switcher
- the previously accepted localization integration set represented by the repository's localization/install tooling

Dhruva remains the largest case: 393 gettext messages, 20 source patches, and generated Polish CLDR metadata for 1907 emoji.

## 2026-09-17 extension refresh

Seven new extensions were accepted after physical-host compatibility testing. Their Polish localization status was reviewed separately from runtime compatibility.

| Extension | Upstream Polish support | Repository work required now |
| --- | --- | --- |
| ArcMenu | Yes; Polish is an upstream-maintained language and `pl.po` was recently updated | No translation from scratch; visual/completeness check only |
| Bluetooth Battery Meter | Yes; upstream `po/pl.po` is current and was revised in September 2026 | No custom translation currently planned |
| Caffeine | Yes; upstream ships `locale/pl.po` | No custom translation currently planned |
| Freon | Yes; upstream ships a Polish `locale/pl/LC_MESSAGES` catalog | No custom translation currently planned |
| GSConnect | Yes, but the current upstream Polish catalog still contains untranslated entries | **Yes — completion/review required** |
| Tiling Shell | Yes, but the current upstream Polish catalog still contains untranslated entries | **Yes — completion/review required** |
| User Themes | Uses the GNOME `gnome-shell-extensions` localization path, which includes Polish for the GNOME 50 branch | No separate repository translation currently planned |

## Result

For the seven newly accepted extensions:

- **0** require a Polish translation from scratch;
- **2** definitely require localization follow-up to reach the repository's preferred fully-Polish UI: **GSConnect** and **Tiling Shell**;
- **5** already have upstream Polish support and do not currently justify a repository-maintained duplicate translation.

Therefore the 2026-09-17 extension refresh adds **2 confirmed translation-completion targets** to the localization backlog, not seven.

## Evidence from upstream catalogs

The GSConnect Polish catalog is active and recently maintained, but currently contains untranslated entries such as `Links` and `Automatically open received URLs`.

The Tiling Shell Polish catalog is also present and compiled upstream, but contains several empty translations, including strings related to best-tile movement, smart border radius, layout synchronization, raising tiled windows together, and screen-edge window suggestions.

Bluetooth Battery Meter has a Polish catalog revised on 2026-09-15. Caffeine ships a Polish source catalog, Freon ships a Polish compiled locale, ArcMenu lists Polish among its maintained translations, and User Themes belongs to the GNOME Shell Extensions localization stream.

## Next step

Before adding repository-managed patches, audit the **exact installed versions** of GSConnect v72 and Tiling Shell v76 and produce a minimal list of untranslated user-visible strings. Prefer upstream Polish translations where available; carry local patches only for demonstrated gaps in the tested workstation versions. Any new localization must be reproducible, reviewable, and covered by `scripts/verify.sh` before acceptance.
