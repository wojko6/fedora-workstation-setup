# Disaster Recovery

This repository remains the canonical **desired-state restore** mechanism for the workstation. A separate private disaster-recovery backup is maintained offline to cover cases where restoring configuration alone is not sufficient.

## Recovery strategy

The recovery model has three independent layers:

1. **Fedora installation media** — official Fedora Workstation Live media provides a clean boot and installation/recovery environment.
2. **Repository-based rebuild** — this repository restores the documented workstation desired state after a clean Fedora installation.
3. **Offline disaster-recovery backup** — a private backup on external storage preserves system and user filesystem state together with the metadata required to reconstruct the original installation.

The offline backup is intentionally **not stored in Git**.

## Validated recovery sets

Two complete disaster-recovery generations are currently retained on offline external storage:

- **2026-09-15** — original validated recovery set;
- **2026-09-17** — refreshed recovery set created after the current Fedora 44 / GNOME 50.4 workstation state reached its accepted physical verification baseline.

The latest 2026-09-17 recovery set contains:

- a read-only Btrfs snapshot stream for the root filesystem;
- a read-only Btrfs snapshot stream for the home filesystem;
- an archive of `/boot`;
- an archive of the EFI System Partition contents;
- partition-table metadata;
- filesystem UUID/PARTUUID metadata;
- the source `fstab`;
- Btrfs subvolume and filesystem-usage metadata;
- UEFI boot-entry metadata;
- kernel and bootloader package information;
- an offline restore guide;
- a SHA-256 manifest covering the recovery artifacts.

The Btrfs streams and the `/boot` and EFI archives were compressed with Zstandard. Compression-stream integrity was tested before finalization. The completed 2026-09-17 recovery set was then verified against its SHA-256 manifest, with every listed artifact passing verification.

The refreshed set contains 15 files and occupies approximately 81 GB. The previous 2026-09-15 generation remains retained separately and was not overwritten.

Temporary local Btrfs snapshots used to produce the refreshed backup were removed only after the external recovery set had passed full verification. The temporary top-level Btrfs mount used during backup creation was also unmounted after cleanup.

## Security and privacy boundary

Machine-specific recovery artifacts must remain private. In particular, do not commit:

- Btrfs send streams or filesystem images;
- `/boot` or EFI backup archives;
- real filesystem UUIDs or PARTUUIDs;
- raw `blkid`, `lsblk`, `efibootmgr`, partition-table, or `fstab` captures from the workstation;
- credentials, SSH private keys, Wi-Fi secrets, browser profiles, VPN authentication state, password-manager data, or other personal state.

This document records the **method and validation result only**. It deliberately contains no machine-specific identifiers or backup contents.

## Restore paths

For ordinary workstation reconstruction, prefer the repository-based path:

```bash
git clone https://github.com/wojko6/fedora-workstation-setup.git
cd fedora-workstation-setup
./install.sh
sudo reboot
cd ~/fedora-workstation-setup
bash scripts/verify.sh
```

Use the private disaster-recovery set when filesystem-level recovery is required. Restoration should be performed from Fedora Live media and must begin by verifying the recovery-set SHA-256 manifest and identifying the target disk before any partitioning or formatting operation.

The exact disk reconstruction procedure depends on the replacement disk and filesystem state, so destructive recovery commands are intentionally not embedded in this public repository.

## Validation status

**Latest offline recovery backup created and integrity-verified: PASS — 2026-09-17.**

The earlier **2026-09-15** generation remains retained as an independent previous recovery point.

This validates backup creation and artifact integrity. It does **not** claim that a full bare-metal restore from the private backup has been exercised. The repository-based clean-room restore is separately validated and documented in [`CLEAN-ROOM-RESTORE-REPORT.md`](CLEAN-ROOM-RESTORE-REPORT.md).
