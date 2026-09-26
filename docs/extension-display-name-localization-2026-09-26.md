# Selective Polish GNOME extension display names — 2026-09-26

## Status

**Physically validated and accepted.**

This follow-up was opened after the User Themes v79 metadata-name localization
was physically confirmed in the GNOME Extensions list.

The goal is not to translate every extension title. The project distinguishes
between:

- descriptive feature names, which may be localized;
- project/brand names, which remain unchanged unless separately justified.

The implementation changes only the `name` field of each exact audited
`metadata.json`. Runtime version, version-name and the pristine metadata
SHA-256 are pinned in `gnome/extension-display-names-pl.tsv`.

## Managed names

| UUID | Version | Pristine display name | Managed Polish display name |
| --- | ---: | --- | --- |
| `add-to-desktop@tommimon.github.com` | 16 | Add to Desktop | Dodaj do pulpitu |
| `advanced-media-controller@sanjai.com` | 31 / 6.5 | Advanced Media Controller | Zaawansowany kontroler multimediów |
| `Bluetooth-Battery-Meter@maniacx.github.com` | 49 | Bluetooth Battery Meter | Wskaźnik baterii Bluetooth |
| `display-brightness-ddcutil@themightydeity.github.com` | 59 | Brightness control using ddcutil | Sterowanie jasnością przez ddcutil |
| `browser-switcher@totoshko88.github.io` | 17 | Browser Switcher | Przełącznik przeglądarki |
| `clipboard-indicator@tudmotu.com` | 71 | Clipboard Indicator | Wskaźnik schowka |
| `ding@rastersoft.com` | 97 | Desktop Icons NG (DING) | Ikony pulpitu NG (DING) |
| `just-another-search-bar@xelad0m` | 18 | Just Another Search Bar | Dodatkowy pasek wyszukiwania |
| `monitorSmartSaver@pic16f877ccs.github.com` | 3 / 1.6.0 | Monitor Smart Saver | Oszczędzanie energii monitora |
| `drive-menu@gnome-shell-extensions.gcampax.github.com` | 82 / 50.4 | Removable Drive Menu | Menu nośników wymiennych |

## Intentionally unchanged project names

The current pass deliberately leaves the following project/brand names
unchanged:

```text
ArcMenu
Blur my Shell
Caffeine
ddterm
Dhruva
GSConnect
Just Perfection
Space Bar
Spotlight
Tiling Shell
Vitals
```

## Fail-closed implementation

`scripts/extension-display-names.py` accepts only two metadata states:

1. the exact pristine file matching the recorded SHA-256 and original name;
2. the exact managed form obtained by changing only the `name` field.

Any other same-version metadata change is rejected.

The dedicated entry points are:

```bash
bash scripts/install-extension-display-names.sh
bash scripts/verify-extension-display-names.sh
```

Advanced Media Controller and Clipboard Indicator already had localization
installers/verifiers pinned to the pristine metadata SHA-256. Those checks are
updated to use the shared managed-metadata verifier so their existing
localization workflows remain fail-closed after the display-name change.

The aggregate localization installer applies display-name changes last, after
the target-specific catalogs/source patches have been handled.

## Acceptance result

The physical Fedora 44 / GNOME Shell 50.5 workstation completed the following acceptance sequence:

1. installed the candidate on the physical Fedora workstation;
2. confirmed all ten metadata files remained valid JSON;
3. diagnosed stale English names as GNOME Shell metadata cache rather than file corruption;
4. logged out and back in to force a complete metadata reload;
5. visually confirmed all ten managed Polish names;
6. passed the dedicated display-name verifier;
7. promoted only the ten affected extension-tree hashes;
8. restored unrelated Space Bar and Dhruva desired-state drift;
9. completed the full physical verifier at `PASS=258 WARN=0 FAIL=0 SKIP=0`.

The selective display-name pass is therefore part of the accepted physical desired state.
