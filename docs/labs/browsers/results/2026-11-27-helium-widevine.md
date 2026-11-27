# 2026-11-27 — Helium Widevine smoke test

**Status: PASS (bounded DRM demo); browser migration and full streaming compatibility HOLD.**

Evidence: operator terminal output and two screenshots supplied on 2026-11-27. This is physical-host reported evidence, not an independently replayed test. Exact installed Helium version was not captured in the supplied final output.

## Configuration

- Existing Microsoft Edge Widevine CDM: version `4.10.3112.1`.
- CDM directory: `/opt/microsoft/msedge/WidevineCdm`.
- User-profile hint: `~/.config/net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm` (or equivalent under XDG_CONFIG_HOME).
- JSON content: `{"Path":"/opt/microsoft/msedge/WidevineCdm"}`.
- Operator output reported hint creation, no system-file or Helium-binary modification. No prior hint backup path was reported. No DRM library was copied or added to Git.

## Evidence

| Check | Result |
| --- | --- |
| Bitmovin public DRM demo (https://bitmovin.com/demos/drm) | Video frames changed between screenshots; page identified Widevine |
| Encrypted Media Extensions / Widevine | Supported |
| Media Source Extensions | Supported |
| requestMediaKeySystemAccess("com.widevine.alpha", ...) | WIDEVINE=SUPPORTED in console |
| Commercial streaming sites | NOT_RUN |
| Resource comparison against Brave | NOT_RUN |
| Post-update persistence / rollback | NOT_RUN |

The console also showed blocked analytics/licensing-related requests and other page-script warnings; these did not prevent the observed demo playback. This does not prove service-wide compatibility, DRM security level, maximum streaming resolution or absence of other errors.

## Maintenance and rollback

The user-local registration depends on the Edge CDM remaining installed and ABI-compatible. Recheck after either browser updates; do not assume version compatibility or persistence. To undo, close Helium, inspect the hint and restore the saved previous hint if one exists, otherwise remove only the lab-created hint after confirming its exact content. Do not remove other profile files or the Edge CDM. Rollback not exercised. No browser-default or desired-state changes approved.
