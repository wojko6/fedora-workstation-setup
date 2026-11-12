# Fedora 45 KDE Graphite — first clean-room VirtualBox plan

**Date:** 2026-11-12  
**Status:** DESIGN ONLY — VM NOT CREATED OR TESTED  
**Tracking:** [Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12)  
**Prerequisite:** [Restore architecture](kde-graphite-restore-plan.md), [Observed host RPMs](../kde/graphite/host-observed-rpms-2026-11-12.tsv).

## Objective

Demonstrate that an **independent Fedora 45 KDE Plasma/Wayland workstation** can be provisioned from reviewed, reproducible configuration in a disposable virtual machine, then add Graphite components incrementally. This is not an ISO build, physical-device recovery, or Fedora 45 acceptance declaration.

## Safety and isolation

- Create a **new throwaway VM** with a new virtual disk; do not attach physical system partitions, external backup disks, existing Fedora VM disks or recovery media as writable block devices.
- Verify the checksum/authenticity of the official Fedora 45 installation image before use. Record the exact ISO filename, expected published checksum and observed digest as part of a private test log, without publishing host paths or personal identifiers.
- Start with a conservative allocation (proposal: 2 vCPUs, 4 GiB RAM and a dynamically allocated 40 GiB virtual disk). Adjust to available host memory; do not promise performance from this sizing.
- Use the VM's own fresh account, no copied SSH keys or personal tokens, and do not share the host's home directory by default. Keep network access bounded to installation/update needs.
- Take a VM snapshot after the clean base install and again before enabling custom Graphite components.
- Never run the repository's current root `install.sh` or `scripts/verify.sh` as an unreviewed KDE restore. They still target the historically accepted Fedora 44/GNOME baseline.
- No raw `~/.config`, private backup payload or secrets belong in the public Git repository.

## Phase sequence

### VM-0 — Fedora 45 vanilla install (not started)

1. Install official Fedora 45 in the disposable VM, selecting a KDE Plasma environment or an otherwise explicitly documented path to KDE.
2. Fully update the guest at a reviewed checkpoint and record repository sources and exact package set. Updates may differ from today's physical-host versions: **the host inventory is observation, not a guaranteed installable lock**.
3. Confirm Wayland session, keyboard layout, basic video, audio, network and storage.
4. Capture a clean rollback snapshot.

### VM-1 — reproducible package baseline (blocked on reviewed manifest)

1. Compare guest RPM names/versions to [observed host inventory](../kde/graphite/host-observed-rpms-2026-11-12.tsv).
2. Define a minimal required package manifest separately from host-only extras and historic kernels. Avoid installing old Fedora 44 kernels or physical NVIDIA drivers inside the VirtualBox guest.
3. Produce an exact-state verifier and a dry-run-only installer on this branch. Reuse safety patterns, not the GNOME installer itself.
4. Record PASS/WARN/FAIL of all expected packages and negative/missing-dependency cases.

### VM-2 — Graphite desktop styling (blocked on reviewed artifact sources)

1. Pin theme, icon, Kvantum, panel, KWin and translation source artifacts with SHA-256 / commits and licensing.
2. Validate neutral dark charcoal background without purple accents (the 2026-11-12 main Finder sidebar remains unresolved).
3. Exercise theme/portal/style interactions and logoff/logon persistence.
4. Verify a rollback to the stock KDE theme and settings.

### VM-3 — Finder / dock / launcher (blocked on reproducible build inputs)

1. Pin Finder source baseline + **all currently uncommitted tracked changes** and P0 patches. A Git HEAD alone is insufficient to reconstruct the physical build.
2. Build Finder in an isolated build tree; verify KIO/file actions, network browse, column view, search, properties and localizations. Never overwrite the system Dolphin.
3. Pin and test Krema and AppBay. Resolve runtime widget/applet identifiers dynamically; do not hard-code host ID `100`.
4. Validate app-to-dock pinning, startup/exit, MIME defaults and use of XDG portals.

### VM-4 — acceptance and promotion (blocked)

- Fresh VM rebuild from a second clean snapshot or virtual disk, with the same pinned inputs.
- Automated status checks plus manual GUI acceptance and screenshot comparison.
- Negative tests, rollback, and no GNOME baseline changes.
- Physical machine-specific checks are **separate**: real NVIDIA/DisplayPort, suspend/resume, physical Bluetooth, removable drives and secure network policy cannot be certified using VirtualBox alone.
- Update the main repository status and restore documentation only after complete evidence is reviewed.

## Minimum evidence record

| Field | Required |
| --- | --- |
| Installation medium | Official Fedora 45 image and verified checksum |
| Guest baseline | Exact release, architecture, desktop session, source repositories |
| Package input | Explicit reviewed manifest, not an unbounded latest-version install |
| Component provenance | Pinned source/commit/digest and patch order |
| Clean-room result | Rebuild from scratch with step-by-step PASS/WARN/FAIL and logs |
| Restore invariants | System Dolphin unaffected, host disks untouched, GNOME installer unchanged |
| Rollback | Verified VM snapshots and isolated Graphite rollback |
| Hardware delta | Explicit list of checks only possible on physical host |

## Current decision

**VM_SETUP_GATE=PLAN_READY, EXECUTION=NOT_STARTED**  
**FEDORA45_KDE_REPRODUCIBLE_RESTORE=HOLD**  
**CUSTOM_ISO=OUT_OF_SCOPE**

No VM creation, package installation, configuration application or baseline promotion is authorized by this document alone.
