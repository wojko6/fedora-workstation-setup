# Disaster Recovery

This repository remains the canonical **desired-state restore** mechanism for the workstation. A separate private disaster-recovery backup is maintained offline to cover cases where restoring configuration alone is not sufficient.

## Recovery strategy

The recovery model has three independent layers:

1. **Fedora installation media** — official Fedora Workstation Live media provides a clean boot and installation/recovery environment.
2. **Repository-based rebuild** — this repository restores the documented workstation desired state after a clean Fedora installation.
3. **Offline disaster-recovery backup** — a private backup on external storage preserves system and user filesystem state together with the metadata required to reconstruct the original installation.

The offline backup is intentionally **not stored in Git**.

For the detailed incident sequence—triage, path selection, integrity checks, storage identification, Btrfs restore, boot/EFI reconciliation, first boot, and final acceptance—use [DISASTER-RECOVERY-RUNBOOK.md](DISASTER-RECOVERY-RUNBOOK.md).

## Validated recovery sets

Validated recovery generations documented by this project include:

- **2026-09-15** — original validated recovery set;
- **2026-09-17** — refreshed recovery set after the earlier Fedora 44 / GNOME 50.4 accepted state;
- **2026-09-21** — current validated recovery set created after the Fedora 44 / GNOME 50.5 physical verifier completed at `PASS=236 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`.

The latest 2026-09-21 recovery set contains:

- a read-only Btrfs snapshot stream for the root filesystem;
- a read-only Btrfs snapshot stream for the home filesystem;
- a separate read-only Btrfs snapshot stream for the nested `/var/lib/machines` subvolume;
- an archive of `/boot`;
- an archive of the EFI System Partition contents;
- GPT/partition-table metadata;
- filesystem UUID/PARTUUID metadata;
- the source `fstab` and `crypttab` capture;
- Btrfs subvolume and filesystem-usage metadata;
- UEFI boot-entry metadata;
- package, Flatpak, kernel, mount, and baseline metadata;
- a SHA-256 manifest covering every recovery artifact and metadata file included in the set.

The Btrfs streams and the `/boot` and EFI archives were compressed with Zstandard. Every compressed artifact passed `zstd -t`. The completed 2026-09-21 set was then verified against a **21-entry** `SHA256SUMS` manifest; every entry passed and the verification command returned `SHA256_VERIFY_RC=0`.

The latest set occupies approximately **164 GiB** on the external recovery drive. It was created as a new dated generation rather than overwriting the documented earlier recovery generations. Backup creation and artifact integrity are validated; a full bare-metal restore onto an empty physical disk is still not claimed as exercised.

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

The exact disk reconstruction procedure depends on the replacement disk and filesystem state, so destructive recovery commands are intentionally not embedded in this public repository. The public [Disaster Recovery Runbook](DISASTER-RECOVERY-RUNBOOK.md) documents the safe decision points and reconstruction order without hard-coding a target device.

## Validation status

**Latest offline recovery backup created and integrity-verified: PASS — 2026-09-21.**

The earlier **2026-09-15** and **2026-09-17** generations remain documented as independent previous recovery points.

This validates backup creation and artifact integrity. It does **not** claim that a full bare-metal restore from the private backup has been exercised. The repository-based clean-room restore is separately validated and documented in [`CLEAN-ROOM-RESTORE-REPORT.md`](CLEAN-ROOM-RESTORE-REPORT.md).


## Documentation roles

The recovery documentation is intentionally split by purpose:

- [RESTORE.md](RESTORE.md) — normal clean Fedora rebuild from the repository;
- [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) — recovery architecture, retained generations, and backup evidence;
- [DISASTER-RECOVERY-RUNBOOK.md](DISASTER-RECOVERY-RUNBOOK.md) — detailed total-failure operational sequence;
- [CLEAN-ROOM-RESTORE-REPORT.md](CLEAN-ROOM-RESTORE-REPORT.md) — evidence from the tested clean-room repository rebuild.
