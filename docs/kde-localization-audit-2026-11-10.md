# KDE Plasma Polish localization — 2026-11-10 field audit

> **Later evidence (2026-11-11):** phases 7–9 were subsequently applied and checked on the physical Fedora 45 workstation; the phase-7 settings labels and phase-9 Panel Colorizer category labels are visibly confirmed. The statements below about phase 7 being *prepared only* describe the **historical state on 2026-11-10**, not the later state. See the [dated November 11 follow-up](WORKLOG-2026-11-11.md) for current evidence, remaining gaps and the separate RPM-owned Plasma sidebar-width change.

> **Environment observed:** Fedora 45, KDE Plasma 6.8.2 / Wayland, user-installed Plasma Flex Hub and Panel Colorizer, with Mac Tahoe-style user widgets.  
> **Evidence class:** operator-provided read-only audit archives, command output, selected QML excerpts, and UI screenshots. Installer/script tests are distinct from physical UI acceptance.  
> **Scope and decision:** user-scoped, separately approved localization changes only. WordCraft is explicitly excluded from local translation work while upstream changes frequently. No issue was opened. This audit does **not** promote Fedora 45/KDE to a reproducible workstation baseline.

## Audit sequence and observations

| Phase | Operator evidence and outcome | Acceptance boundary |
| --- | --- | --- |
| 1 — inventory | Initial inventory counted 3,740 RPM packages, 190 desktop-entry records, 39 KDE/SDDM additions and 881 Polish translation resources. | Inventory counts are not error counts; archived duplicate `.desktop` entries were identified. |
| 2 — filtered inventory | 162 distinct applications, 472 inspected desktop-entry fields, 347 fields with `[pl]` data and 49 requiring review; 13 QML candidates. | Missing `Name[pl]` does not always mean that a displayed name is English. |
| 3 — source and catalog review | 10 KDE metadata records, 68 desktop fields and 14 catalog checks. | Exact-source review was used to select safe, narrowly scoped changes. |
| 4 — local patch | Operator-reported `PASS`: seven modified user files, three QML `i18n()` bindings and nine localized metadata fields across Flex Hub and Tahoe widgets; a backup was created. | A new Plasma session made the translated Flex Hub description visible; `Dark` / `Light` were later visibly Polish. |
| 5 — local patch | Operator-reported checks `8/8`, stage `PASS`; user subsequently reported successful application and a new KDE login. Three QML strings and one Panel Colorizer label were linked to Polish gettext entries (five files in the stage). | Screenshots confirmed `Add Sensor` → `Dodaj czujnik` and `Panel Spacer` → `Odstęp na panelu`. The two demo strings were visibly Polish but truncated in narrow preview widgets, so their **full rendered wording was not established**. |
| 6 — inventory | 160 QML/JavaScript files; 565 localization calls, 94 missing Polish catalog matches and 138 candidate literals. | These are candidates, **not** 232 confirmed translation defects. |
| 6 — applied changes | Operator-reported `--check=PASS_READ_ONLY` and `--apply=PASS`: 77 newly added or corrected translations (17 Flex Hub, 60 Panel Colorizer) and a single QML label binding (`select sensor`), in two `.mo` files plus `BuilderConfig.qml`. | First post-login weather screenshot confirms Polish location, unit and heading texts, but other metric labels remain English. The full Panel Colorizer instruction surface and sensor-selection label were **not** rechecked after phase 6. |
| 7 — prepared only | A separate ten-entry weather gettext addition (without QML changes) was assembled and passed seven assistant-side offline tests, with earlier catalog entries retained in the test artifact. | **NOT DEPLOYED / NOT TESTED ON HOST.** The operator deferred `--self-test`, `--check`, `--stage` and any future installation to the next session. |

The phase-4/6 backup copies remain on the workstation, outside Git. No private audit ZIP, screenshot, binary catalog, host backup or exact personal path is published by this report.

## Confirmed remaining Flex Hub localization gap

A screenshot of the **Weather** settings after phase 6 showed these elements in Polish: IP-based location choice, coordinate search, wind/temperature units and the **Weather Metrics** heading. The tab title `Weather` and the following metric labels remained English:

`Wind Speed`, `Feels Like`, `UV Level`, `Humidity`, `Rain`, `Max/Min`, `Sunrise / Sunset`, `Cloud Cover`.

The operator's read-only source inspection established:

- `contents/ui/WeatherConfig.qml` uses literal English `ListElement.name` values as **persistent metric identifiers**. The visible checkbox label is `i18n(model.name)`.
- `contents/ui/components/MainView.qml` matches saved identifiers against `listMetrics[].name`, then renders a `nameText` through `i18n(namesTitles[modelData])`; sunrise/sunset has a conditional localized display path.
- Dynamic gettext keys are easy to omit from translation extraction. The planned catalog-only completion contains ten source terms (the eight metrics plus displayed aliases `Wind` and `Cloudiness`). **Do not translate or replace the internal identifier keys**. In particular, do not insert an `i18n(...)` expression directly into static QML `ListElement` declarations.

Separate observations, **not part of this translation patch**:

- `MainView.qml` appears to use `weatherData.currentWeather` for the humidity percentage, although `currentHumidity` exists in `WeatherData.qml`.
- The `Rain` metric appears to use `dailyWeatherMax[0]`, which may represent maximum temperature, not rainfall.
- Narrow profile/preview controls truncate names and can split long labels.
- Remaining UI candidates include the `Weather` tab name and certain English preset/model labels. Audit whether they are translatable UI or intentionally preserved product names before editing.

These are hypotheses requiring functional/source validation; do not attribute a sensor or weather-data defect to localization by assumption.

## Panel Colorizer review

Before phase 6, the **Widget Islands** page was mixed Polish/English. The `Panel Spacer` dropdown option was visibly translated after phase 5; instructional headings and text such as `How to use`, `Notes`, `Separator widget`, `Require two separators per island`, and `Blacklist separator widgets` remained English. Sixty catalog additions were installed in phase 6, but that entire page has **not** yet had a post-patch visual acceptance pass. Preserve markup/links and placeholders when reviewing the remaining entries.

## KDE session incident after phase 6

After a normal logout/login, the operator observed a plain blue display without the desktop and moved to TTY3. The host was accessible; `plasma-plasmashell.service` and `plasma-kwin_wayland.service` both reported **active (running)**, and XWayland was present. The Plasma journal repeatedly mentioned Flex Hub `SourceBright...` and `FullRepresentation.qml` QML errors. The user subsequently confirmed that the desktop was operational again. The precise recovery action and root cause were **not established**.

- This is an **observed temporary graphical-session incident**, not proof that the new localization catalogs caused it.
- No NVIDIA kernel crash or complete Fedora outage is established from the supplied evidence.
- Avoid changing KWin, the GPU stack or full Plasma configuration as a localization workaround without a separate diagnosis.
- If it recurs, collect complete non-truncated relevant QML log lines and timestamped session status before destructive changes.

## Change control and release status

- The changes were **operator-run on the physical host**, not executed remotely by the assistant.
- For local QML, preserve upstream English msgids, use KDE `i18n()` for visible strings and keep saved identifiers stable; for metadata use `Name[pl]` / `Description[pl]` without renaming IDs.
- Tests, stage-only plans and checked SHA-256 inputs are not equivalent to a visually accepted live UI. Re-login may be required for Plasma to reload metadata/catalogs.
- Keep user-level before/after hashes, explicit confirmation, backups and a conflict-aware rollback plan. Do not silently overwrite upstream updates.
- The staged edits and compiled catalogs are **not yet a reproducible repo-managed Fedora 45 localization installer**. Archive reviewed source translations and build/verify logic before claiming desired-state restoration.
- WordCraft: **observe upstream translation progress only**, no local patching.
- Historical Fedora 44/GNOME clean-room and verification totals retain their original dates and acceptance scopes.

## Next-session checkpoint (2026-11-11; not an automation)

1. Run the previously supplied phase-7 script **self-test**, **read-only check**, then **stage** on the workstation and inspect its staged ZIP. Do not assume the operator ran any of these on 2026-11-10.
2. Review the ten English → Polish dynamic metric msgids and verify that metric selection/persistence is unchanged; only after review authorize and deploy a catalog change with a separate backup.
3. Start a new Plasma session if needed, and visually check all eight weather metrics, the two displayed aliases, the `Weather` tab title and the selected metrics in the actual control-center UI.
4. Verify the phase-6 `Wybierz czujnik` button and the full Panel Colorizer Widget Islands instruction page; record residual gaps rather than marking all 77 messages visually accepted.
5. Investigate unrelated `SourceBright...` QML errors or wrong weather-data bindings separately if observed again.
6. Keep Fedora 45/KDE full desired-state promotion **HOLD** pending a clean-room restore and comprehensive verifier run.

## Related documentation

- [2026-11-10 workstation worklog](WORKLOG-2026-11-10.md)
- [Localization status and legacy GNOME baseline](LOCALIZATION-STATUS.md)
- [KDE Tahoe B291/B292 archival sources](../localization/kde-tahoe/README.md)
- [Flex Hub functional patches (separate from translations)](../patches/kde-tahoe/flex-hub/README.md)
- [Fedora 45 upgrade and acceptance gates](UPGRADE.md)
