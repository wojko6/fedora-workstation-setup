# Fedora 45 KDE Graphite — package and Finder provenance checkpoint

**Date:** 2026-11-12  
**Evidence:** operator console output from `scripts/inventory-kde-graphite-provenance-readonly.sh --read-only` (v0.1).  
**Result:** `INVENTORY_RESULT=READ_ONLY_COMPLETE`, `CHANGES_APPLIED=NO`; **restore acceptance remains HOLD**.

## Package observations

The host reported Fedora 45 KDE/Wayland with the following installed RPM versions (x86_64 unless otherwise noted):

| Package / group | Observed version(s) |
| --- | --- |
| plasma-workspace / plasma-desktop | 6.8.2-1.fc45 |
| kwin | 6.8.2-3.fc45 |
| kf6-kio, kf6-kconfig, kf6-kwidgetsaddons | 6.31.0-1.fc45 |
| kde-cli-tools | 6.8.2-1.fc45 |
| qt6-qtbase / qt6-qtbase-gui | 6.11.2-3.fc45 |
| xdg-desktop-portal | 1.22.1-2.fc45 |
| xdg-desktop-portal-kde | 6.8.2-1.fc45 |
| xdg-desktop-portal-gtk | 1.15.3-6.fc45 |
| pipewire | 1.6.11-1.fc45 (**x86_64 and i686**) |
| wireplumber | 0.5.19-1.fc45 |
| flatpak | 1.19.0^really1.18.4-1.fc45 |
| krema | 0.13.0-1.fc45 |
| kvantum | 1.1.6-2.fc45 |
| akmod-nvidia, xorg-x11-drv-nvidia, xorg-x11-drv-nvidia-cuda | 620.70.06-1.fc45 |
| kernel-core | 7.2.13-200.fc44, 7.2.15-200.fc44 and 7.3.3-300.fc45 (**all x86_64**) |

The query for the separately named `akmod-nvidia-open` returned the localized RPM text “not installed”. **This does not establish whether the running NVIDIA kernel module is proprietary or open.** The installed `akmod-nvidia` package and actual loaded module must be investigated separately if relevant.

The original v0.1 audit had a format bug: multiarch/multi-version results were **concatenated without separators**, and localized “package not installed” output leaked into a data value. The [v0.2 read-only helper](../scripts/inventory-kde-graphite-provenance-readonly.sh) now uses newline-delimited `rpm --qf` output with semicolon separators and explicit `NOT_INSTALLED`; this is a script correction and not yet an operator-confirmed v0.2 run.

The normalized [host-observed RPM table](../kde/graphite/host-observed-rpms-2026-11-12.tsv) is a **non-installable observational manifest**, not a package lock. The old Fedora 44 kernels are retained on the host; they must not be added to an independent Fedora 45 guest's install manifest.

## Finder source / artifact observations

| Element | Observation |
| --- | --- |
| Finder source HEAD | `1e02adccdb85f18d0a080b3a7383c13916176237` |
| Tracked modified files | **9** |
| P0-B2 test executable SHA-256 | `03ece349499fea56689e8030c45ff382edc9f2079cd8454433f67ef9074522e6` |
| P0-B2 QSS SHA-256 | `146dc18a7d53d75bd15c86ad8433ea97492eb00082b6d8883dd9e22ee2851277` |
| Charcoal v0.4 candidate SHA-256 | `e8d540fe94eb85a9ba1bbadf15a0733960fb594230b5fdd94aab3340f4a00e19` |

**Critical reproducibility gap:** A source HEAD plus nine tracked modifications does **not** identify the exact code state used for the local binary. Before any clean-room rebuild, archive or commit a reviewed source patch set and record its precise base commit, hash, build environment and order. No raw source tree or sensitive paths should be copied into public Git without inspection.

A successful `sha256sum` only proves file identity for these local artifacts; the source and binary/QSS bytes are **not** yet present as independently reproducible pinned deliverables in this branch. Charcoal v0.4 is still a GUI candidate (main sidebar tint unresolved).

## Actions and next gate

- `INVENTORY_V01=HOST_OBSERVED`.
- `INVENTORY_V02_SCRIPT=FORMAT_CORRECTED_PENDING_HOST_RECHECK`.
- `G1_FULL_ARTIFACT_PROVENANCE=HOLD`.
- `G2_INSTALLER=HOLD`; `G3_VM_CLEAN_ROOM=NOT_STARTED`; `G7_PROMOTION=HOLD`.
- First [VirtualBox clean-room plan](kde-graphite-clean-room-vm-plan.md) is written but execution is not authorized by this report.

No system packages were installed or removed; no KDE or Finder source/QSS changes were performed in this audit; no production launcher was switched.
