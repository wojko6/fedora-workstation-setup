# Disaster Recovery

This repository remains the canonical **desired-state restore** mechanism for the workstation. A separate private disaster-recovery backup is maintained offline to cover cases where restoring configuration alone is not sufficient.

## Recovery strategy

The recovery model has three independent layers:

1. **Fedora installation media** — official Fedora Workstation Live media provides a clean boot and installation/recovery environment.
2. **Repository-based rebuild** — this repository restores the documented workstation desired state after a clean Fedora installation.
3. **Offline disaster-recovery backup** — a private backup on external storage preserves system and user filesystem state together with the metadata required to reconstruct the original installation.

The offline backup is intentionally **not stored in Git**.

## Validated recovery set — 2026-09-15

A disaster-recovery set was created from the physical Fedora workstation on 2026-09-15.

The set contains:

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

The Btrfs streams were compressed with Zstandard. Compression-stream integrity was tested before finalization. The completed recovery set was then verified against its SHA-256 manifest, with every listed artifact passing verification.

Temporary local Btrfs snapshots used to produce the backup were removed only after the external recovery set had passed verification.

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

**Offline recovery backup created and integrity-verified: PASS — 2026-09-15.**

This validates backup creation and artifact integrity. It does **not** claim that a full bare-metal restore from the private backup has been exercised. The repository-based clean-room restore is separately validated and documented in [`CLEAN-ROOM-RESTORE-REPORT.md`](CLEAN-ROOM-RESTORE-REPORT.md).
