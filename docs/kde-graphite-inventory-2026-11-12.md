# Fedora 45 KDE Graphite — host inventory checkpoint

**Date:** 2026-11-12  
**Source:** Operator-supplied console output of `bash scripts/inventory-kde-graphite-readonly.sh --read-only` on the running physical Fedora host.  
**Status:** HOST INVENTORY PASS (bounded); **reproducible restore remains HOLD**.  
**Scope:** Observation only; not a clean-room build, install verification, or complete system validation.

## Reported results

| Check | Observation |
| --- | --- |
| Inventory execution | `INVENTORY_RESULT=READ_ONLY_COMPLETE` |
| Current OS | `fedora`, version `45` |
| Session | `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=KDE` |
| Kernel | `7.3.3-300.fc45.x86_64` |
| `plasma-workspace` | `6.8.2-1.fc45` |
| `kwin` | `6.8.2-3.fc45` |
| `kf6-kio` | `6.31.0-1.fc45` |
| `kde-cli-tools` | `6.8.2-1.fc45` |
| Tools present | `rpm`, `dnf5`, `flatpak`, `cmake`, `ninja`, `krema`, `plasmashell`, `dolphin`, `kreadconfig6` |
| Config file presence | `kdeglobals`, `kwinrc`, `kglobalshortcutsrc`, `plasma-org.kde.plasma.desktop-appletsrc` |
| Local Finder LAB | source exists, test binary `build-p0b2-v01/bin/finder` exists |
| Finder QSS candidate | Charcoal v0.4 file exists; SHA-256 `e8d540fe94eb85a9ba1bbadf15a0733960fb594230b5fdd94aab3340f4a00e19` |
| File/config export | `CONFIG_CONTENTS_EXPORTED=NO`; `MACHINE_IDENTIFIERS_EXPORTED=NO` |
| Mutations | `CHANGES_APPLIED=NO` |
| Restore acceptance | `ACCEPTED_BASELINE=NO` |

The checksum identifies a local **candidate file** and is *not* evidence that its bytes are stored in Git, that it is the active launcher theme, or that its user interface passed complete acceptance. The initial inventory checked only presence, not hashes of all dependencies. Package strings are local observations, not a complete dependency lock.

## What this establishes

1. The opt-in read-only helper can collect coarse Fedora 45/KDE/Graphite context without reading private desktop configuration content.
2. Several essential components for a future reproducible profile are available on the running machine.
3. The manifest matrix may be annotated with these observed host versions and candidate checksum.

## Still not established

- Source provenance, pinned commit and licensing of all Finder/Krema/AppBay/Tahoe/Flex Hub components.
- A reviewed, exportable KDE configuration with sensitive values removed.
- Hardware-independent Fedora 45 KDE build profile and package dependency lock.
- Exact reproducible Finder source patch stack and matching binary build instructions.
- Graphite UI acceptance (especially purple-tinted main sidebar in the latest screenshot), full localization and file/KIO regressions.
- Clean-room VM replay, alternate-host restoration, or physical bare-metal restore.
- Integration checks for XDG portals, default applications, keyring, external DisplayPort and GPU suspend/resume.
- A safe independent KDE installer: the old `install.sh` still targets the historical GNOME baseline.

## Next gated action

Use a further **read-only** provenance audit to capture safe package names/versions, the active Finder wrapper target (without printing personal paths), hashes and Git origin information *after redaction*. Do not upload raw configuration files or private disk metadata. Then propose the first disposable VM package set. Keep all gates G1-G7 at HOLD until their individual acceptance criteria are met.

Tracked by [Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12) and the [Graphite restore plan](kde-graphite-restore-plan.md).
