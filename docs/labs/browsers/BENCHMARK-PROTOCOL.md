# Browser benchmark protocol — v0.1

Status: planned, not yet executed. Use deterministic local measurement scripts rather than AI for data collection.

## Environment

Record date, Fedora/kernel, desktop/session, CPU/GPU, RAM, driver, browser version and package source. Reference hardware: Legion 5, Ryzen 7 5800H, RTX 3060 Laptop, 16 GB installed RAM; record actual usable RAM. Keep display resolution, refresh rate, power profile, thermal conditions, network/DNS/Pi-hole policy and background workload fixed. Record memory PSI and swap activity; postpone runs under material memory pressure or concurrent builds. Do not disable swap, sandboxing, SELinux or security protections.

## Scenarios

Use separate temporary browser profiles (no production cookies, sync or account credentials). Compare default configurations first, then matched blocking settings where supported; record exact filter lists and extension versions. Use identical public URLs and/or local fixtures, fixed tab order, viewport and settling time. Keep tab sleeping/discarding settings recorded; verify tabs remain loaded. Run browsers sequentially, not simultaneously. Alternate order across at least three repetitions; report median and range. Distinguish warm and cold application starts; do not drop system caches.

| ID | Workload | Measurements |
| --- | --- | --- |
| B01 | Startup / blank tab | Time to usable window, idle PSS, CPU |
| B02–B05 | 1 / 5 / 10 / 20 matched loaded tabs | PSS, SwapPss, CPU time, tab state, responsiveness |
| B06 | Same public video, fixed codec/resolution/length where possible | CPU time, GPU/video decode, dropped frames, PSS |
| B07 | Local ad-filter fixture and representative public pages | Blocked requests, breakage, equivalent content |
| B08 | Public DRM demo, then optional operator-only streaming smoke | EME/CDM support, actual playback |
| B09 | Representative web apps | Compatibility, crashes, usability; private tests reported only as sanitized status |

## Measurement

- Sum proportional set size (PSS) and SwapPss from /proc/PID/smaps_rollup for the complete identified browser process group/tree, including GPU, renderer and utility processes; avoid double-counting PIDs. Report missing/vanished processes and sampling limits. RSS is diagnostic only.
- Measure CPU time delta (user + system) for a fixed interval, accounting for process churn where possible; report interval and limitations. Sample at consistent times. Record GPU utilization and VRAM only where reliable per-process attribution is available; otherwise label system-wide or unavailable.
- Record startup measurement method, crashes, failed pages, tab discard, codec and dropped frames. Capture raw sanitized measurements privately and publish aggregates only.
- Use MiB for memory and seconds for CPU/startup. Record baseline idle host pressure, versions and configuration each run. Mark unmeasured values NOT_RUN, not zero.

## Acceptance

A proposed migration requires functional parity for operator-required workflows, maintained security updates, working filtering and no material regressions. A provisional efficiency target is at least 15% lower median PSS in the matched 10-tab scenario, with consistent repetitions and no material CPU/latency penalty; this is a lab decision threshold, not a measured result. Smaller differences may still justify a trial. DRM demo success alone does not certify individual commercial streaming sites. Experimental browsers must remain isolated from sensitive accounts until security maturity is assessed. No change to default browser or repository desired state without explicit operator acceptance.

## Result template

Date; scenario ID; browser/version; profile/filter settings; host/software versions; run count; PSS MiB median/range; SwapPss MiB; CPU seconds; startup seconds; GPU/VRAM scope; failures; limitations; status PASS/FAIL/HOLD/NOT_RUN. Include evidence provenance and rollback notes for any actual configuration change.
