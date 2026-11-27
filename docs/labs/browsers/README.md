# Graphite Efficiency Lab — Browser comparisons

**Status: experimental / no default-browser migration approved.**

This lab compares real-world browser resource use, functionality, privacy controls and maintenance costs on the Fedora workstation. A browser's implementation language alone is not evidence of efficiency.

## Candidates

| Browser | Role | Current evidence |
| --- | --- | --- |
| Brave | Production reference | Benchmark pending |
| Helium | Chromium-based candidate | Installed; bounded Widevine smoke test passed on 2026-11-27 |
| Ladybird | Independent-engine experimental candidate | Not benchmarked; pre-release maturity and security must be reviewed before use |
| Servo-based browsers (e.g. Hermes) | Research candidates | Not benchmarked; no production recommendation |

## Records

- [Benchmark protocol](BENCHMARK-PROTOCOL.md) — repeatable workloads, measurements and acceptance gates.
- [2026-11-27 — Helium Widevine](results/2026-11-27-helium-widevine.md) — bounded operator-reported DRM smoke test.
- Future results: `results/YYYY-MM-DD-<browser-or-comparison>.md`, with sanitized machine-readable aggregates where useful.

## Next steps

1. Record exact installed versions and settings of Brave and Helium.
2. Run matched PSS/CPU tests for 1, 5, 10 and 20 tabs, beginning with small workloads.
3. Check functionality, filtering, media acceleration, DRM and security/update policy.
4. Compare repeated measurements and decide whether further trials are warranted.

Do not publish browser profiles, history, credentials, cookies, tokens, DRM binaries, private URLs or raw diagnostic dumps containing identifying data. This lab does not change package manifests, install scripts, browser defaults or the historical accepted Fedora 44/GNOME restore baseline. Fedora 45/KDE restore acceptance remains HOLD.
