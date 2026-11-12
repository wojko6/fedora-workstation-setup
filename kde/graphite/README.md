# KDE Graphite profile (design stage)

**Target:** Fedora 45 / Plasma 6.8.2 / Wayland / Graphite dark UI  
**State:** LAB DESIGN, not installable or accepted; **do not use this profile for system recovery yet**.

This directory is the proposed home for an opt-in desktop profile within the existing Fedora workstation repository. It complements the GNOME restoration work; it does not supersede it.

## Current evidence

- The physical host runs Fedora 45/KDE according to the dated [project status](../../PROJECT-STATUS.md).
- Local Finder LAB experiments include a P0-A source patch, compact search progress UI, a P0-B2 search-style ownership change, and candidate Graphite Charcoal QSS. These are *operator GUI/build checkpoints*, **not** pinned repository-managed artifacts.
- The 2026-11-12 visual reference is the dark Finder "Information about…" dialog. Target backgrounds are neutral charcoal, with no purple or bright blue selection fill. The main sidebar's violet tint is **not accepted**.
- A working local build or successful visual screenshot alone does not prove clean-room recreation or long-term maintenance.

## Repository boundaries

- [Restore design and acceptance gates](../../docs/kde-graphite-restore-plan.md)
- [Component matrix](component-matrix.tsv)
- [Read-only host inventory helper](../../scripts/inventory-kde-graphite-readonly.sh)
- [Existing GNOME restore instructions](../../docs/RESTORE.md) — historical accepted flow; **not to be run as a KDE installer**
- [Existing KDE coexistence Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12)

## Planned layout (not yet implemented)

- `manifests/` — reviewed rpm/Flatpak/theme/application references, commits and SHA-256 pins
- `patches/` — reviewed Finder source/QSS and KDE widget changes with upstream provenance
- `restore/` — opt-in, target-checked installer with dry-run and rollback
- `tests/` — static, isolated build, clean-room and GUI checks

These directories are **a design proposal** and do not exist yet. Avoid adding local, unreviewed copies of entire user configurations or binary apps.

## First collection pass

Run only the non-mutating helper on the production host:

```bash
bash scripts/inventory-kde-graphite-readonly.sh --read-only
```

It prints no config contents, credentials, UUIDs, hostnames, home-directory paths or tokens. Inspect output before pasting it into a public discussion. The results are hints for a later curated manifest, not an automatic trust source.

## Bounded host inventory checkpoint — 2026-11-12

The first read-only inventory completed on the physical Fedora 45/KDE Wayland host. Its reported package versions and the local Charcoal v0.4 candidate SHA-256 are recorded in [the dated inventory checkpoint](../../docs/kde-graphite-inventory-2026-11-12.md). This confirms host observations, **not** a reproducible install.

The next opt-in **read-only** audit collects only a fixed list of RPM versions, the Finder source HEAD / count of tracked modifications (no file list or remote URL), and hashes of three local Finder artifacts:

```bash
bash scripts/inventory-kde-graphite-provenance-readonly.sh --read-only
```

Review the output before sharing. No raw configuration or private data export is intended.

**Do not run** `./install.sh` as a substitute. No current branch has an approved Fedora 45 KDE installer.
