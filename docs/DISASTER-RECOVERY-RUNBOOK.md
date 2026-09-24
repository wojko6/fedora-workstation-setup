# Disaster Recovery Runbook

This runbook describes the **public, machine-agnostic recovery procedure** for the Fedora workstation after a severe or total failure. It complements [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md), which documents the recovery strategy and retained backup generations, and [RESTORE.md](RESTORE.md), which documents the normal clean rebuild path.

The runbook intentionally omits private identifiers, real UUID/PARTUUID values, raw disk captures, credentials, and copy-paste destructive partitioning commands. Those belong only to the private offline recovery set.

## Scope

Use this runbook for failures such as:

- a dead or replaced system SSD;
- a workstation that no longer boots;
- severe Btrfs corruption;
- loss of the partition table or EFI boot path;
- a recovery where the previous filesystem state must be reconstructed;
- a clean replacement build after a total host loss.

For ordinary configuration drift, GNOME problems, package drift, or a single broken component, prefer the repository restore/repair path rather than a full disaster-recovery operation.

## Recovery model

The workstation uses three independent recovery layers:

1. **Fedora Workstation Live media** — an independent environment for diagnosis, installation, mounting, and recovery.
2. **Repository-based rebuild** — this repository reconstructs the reviewed workstation desired state on a clean Fedora installation.
3. **Private offline disaster-recovery set** — filesystem streams and machine metadata retained on external storage for filesystem-level or bare-metal recovery.

The preferred outcome is the **least destructive recovery path that restores a verified system**.

## Phase 0 — stop and preserve evidence

After a severe failure:

1. Do not immediately repartition, format, reinstall, or overwrite the affected disk.
2. If the disk may be failing physically, minimize writes to it.
3. Boot trusted Fedora Workstation Live media.
4. Connect the offline recovery drive only when needed.
5. Record what is still visible before changing anything.

Useful read-only or observational checks include:

```bash
lsblk -f
blkid
sudo efibootmgr -v
sudo btrfs filesystem show
```

If storage hardware is unstable, prioritize data preservation before repair attempts.

## Phase 1 — classify the failure

Determine which layer is actually broken.

### Boot-only failure

Typical symptoms:

- firmware sees the disk;
- partitions and filesystems are present;
- Btrfs mounts successfully;
- the system fails in the EFI/bootloader/kernel/initramfs chain.

Recovery scope should remain limited to the boot path. Do not rebuild the root filesystem if it is healthy.

### Filesystem or operating-system failure

Typical symptoms:

- Btrfs cannot be mounted normally;
- root or home data is damaged;
- a clean reinstall is safer than trying to repair the existing installation.

Choose between the repository rebuild and offline filesystem restore depending on whether the previous exact filesystem state is required.

### Total disk loss

Typical symptoms:

- system SSD is missing or unreadable;
- replacement storage is installed;
- no usable partition table or filesystems remain.

This is the full disaster-recovery case.

## Phase 2 — choose the recovery path

### Path A — clean rebuild from Fedora + repository

Prefer this when:

- personal/private data exists in separate backups;
- the old filesystem does not need to be reproduced exactly;
- a fresh, reviewed system is preferable to restoring historical system state;
- the replacement disk can receive a normal Fedora installation.

High-level flow:

```text
new or repaired disk
        ↓
clean Fedora installation
        ↓
fully update base system
        ↓
clone fedora-workstation-setup
        ↓
restore required private local configuration
        ↓
run install.sh
        ↓
restore private user data and authentication state
        ↓
reboot or restart GNOME session
        ↓
run scripts/verify.sh
        ↓
accept only after verification
```

See [RESTORE.md](RESTORE.md) for the normal clean rebuild procedure.

### Path B — filesystem-level / bare-metal restore

Use this when:

- the previous root/home filesystem state is required;
- files not covered by another backup must be recovered;
- reproducing the earlier machine state is more important than starting clean;
- the repository alone cannot reconstruct required private state.

The offline recovery set is the source of truth for this path.

## Phase 3 — verify the offline recovery set before using it

Do not begin reconstruction from an unverified recovery set.

The validated recovery generations are documented in [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md). The latest validated offline set was created on **2026-09-21** after a clean `PASS=236 WARN=0 FAIL=0 SKIP=0` physical verifier run and includes a 21-entry SHA-256 manifest. The desired-state repository baseline was subsequently re-accepted on **2026-09-24** at `PASS=256 WARN=0 FAIL=0 SKIP=0`, `VERIFY_RC=0`; treat the dates separately and do not assume the older DR image contains every later desired-state change.

From the directory containing the recovery set, verify the manifest before restoring anything:

```bash
sha256sum -c SHA256SUMS
```

Use the actual manifest filename from the private recovery guide if it differs.

Stop if:

- any checksum fails;
- an expected artifact is missing;
- compressed-stream integrity fails;
- the external recovery drive reports I/O errors.

The backup must be treated as untrusted until integrity checks pass.

## Phase 4 — identify source and target storage

Before any operation that can alter a disk, positively identify:

- Fedora Live media;
- the offline recovery drive;
- the failed or replacement system SSD;
- any other attached disks that must not be modified.

Use several independent signals such as:

- device model;
- capacity;
- transport type;
- filesystem labels;
- existing partition layout;
- mount points.

Useful inspection commands include:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS
blkid
```

Do **not** copy a device name from an old note and assume it still refers to the same disk. Device names can change between boots and hardware configurations.

## Phase 5 — reconstruct the target disk only from private metadata

For a replacement or completely empty disk, reconstruct the required storage layout using the private recovery metadata.

The private recovery set contains reference material for:

- GPT/partition-table layout;
- EFI System Partition;
- filesystem identifiers;
- Btrfs layout;
- source `fstab`;
- UEFI boot entries.

The public repository deliberately does not include executable partitioning commands because a wrong target device would be destructive.

Before committing a new partition table, confirm the target disk again.

Conceptually, the required structure is:

```text
replacement system disk
├── EFI System Partition
└── Fedora filesystem
    ├── root Btrfs subvolume/state
    └── home Btrfs subvolume/state
```

The exact structure must follow the private recovery metadata and the current Fedora boot requirements.

## Phase 6 — restore Btrfs filesystem state

The latest offline set contains read-only Btrfs snapshot streams for root, home, and the nested `/var/lib/machines` subvolume.

Conceptually:

```text
root snapshot stream     ──► btrfs receive ──► restored root state
home snapshot stream     ──► btrfs receive ──► restored home state
machines snapshot stream ──► btrfs receive ──► restored /var/lib/machines state
```

The streams were generated from read-only snapshots and compressed with Zstandard.

Before restore:

1. verify the compressed stream;
2. verify the SHA-256 manifest;
3. mount the target Btrfs filesystem at a controlled recovery mount point;
4. confirm the destination does not contain unrelated data;
5. receive the streams into the intended target filesystem.

Do not receive a stream into an arbitrary mounted filesystem merely because it has sufficient free space.

After receive, inspect the resulting subvolumes and mount relationships before proceeding.

## Phase 7 — restore boot state

A Fedora system cannot be reconstructed from the root Btrfs state alone. The recovery set therefore also preserves the boot chain.

### Restore `/boot`

Restore the private `/boot` archive to the intended boot filesystem/location.

This contains state associated with kernels, initramfs images, and bootloader integration present when the recovery generation was created.

### Restore the EFI System Partition

Restore the saved EFI System Partition content to the target ESP.

The expected boot chain is:

```text
UEFI firmware
      ↓
EFI System Partition
      ↓
Fedora bootloader
      ↓
kernel
      ↓
initramfs
      ↓
root filesystem
```

### Reconcile UEFI boot entries

The recovery set contains UEFI boot-entry metadata as reference material. Firmware NVRAM may not preserve old entries after motherboard reset, disk replacement, or firmware changes.

Compare the current `efibootmgr -v` output with the private recovery metadata and restore the required Fedora boot entry when necessary.

Do not assume that copying EFI files alone guarantees that the firmware will present the correct boot target.

## Phase 8 — reconcile UUIDs, PARTUUIDs, and fstab

A replacement disk or recreated filesystem may not have the same identifiers as the original installation.

The private recovery set includes:

- original UUID/PARTUUID information;
- the source `fstab`;
- partition and filesystem metadata.

Treat these as **reference data**, not as values to copy blindly.

Compare:

```text
original recovery metadata
          +
current lsblk/blkid output
          ↓
validated current mount configuration
```

Before the first normal boot, ensure that mount configuration refers to the correct current filesystems and that the required root, home, boot, and EFI relationships are coherent.

## Phase 9 — first boot after filesystem-level recovery

The first boot is a validation event, not proof that recovery is finished.

Confirm the boot chain in order:

1. UEFI sees the intended Fedora boot entry.
2. The bootloader loads.
3. The expected kernel and initramfs load.
4. The root filesystem mounts.
5. The home filesystem mounts.
6. The graphical session starts.

If the system fails at one layer, return to that layer rather than modifying unrelated parts of the recovered system.

## Phase 10 — post-boot security and platform checks

After the recovered system boots, verify the controls that are material to this workstation.

At minimum review:

- Btrfs mounts and expected subvolumes;
- `/boot` and EFI mount state;
- networking;
- SELinux enforcing state;
- Secure Boot state;
- active kernel;
- NVIDIA module loading;
- NVIDIA module signing path;
- kernel lockdown state;
- required services;
- GNOME session state.

This workstation's accepted desired state includes Secure Boot with a signed NVIDIA kernel-module path and kernel lockdown in integrity mode. A successful graphical login does not by itself prove those controls are restored.

## Phase 11 — reconcile the recovered snapshot with the current desired state

The offline disaster-recovery generation represents a point in time. The current repository may have advanced since that backup was created.

The 2026-09-21 generation was created immediately after the current accepted `PASS=236` baseline, but every recovery generation is still a point-in-time snapshot and the repository can advance later.

Therefore:

1. boot and validate the recovered filesystem state first;
2. update the checked-out repository to the intended reviewed revision;
3. review differences between the recovered state and current desired state;
4. run only the required controlled restore/update stages;
5. restart the GNOME session or reboot when required;
6. run the full verifier.

Do not assume that an older filesystem snapshot is automatically equal to the latest desired state.

## Phase 12 — final acceptance

The final acceptance command is:

```bash
bash scripts/verify.sh
```

The current accepted physical-workstation reference is:

```text
PASS=236 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

That exact count is tied to the current implemented verifier and desired state. Future repository changes may legitimately change the absolute PASS count.

The durable acceptance rule is:

- `VERIFY_RC=0`;
- zero required-state `FAIL`;
- zero unresolved actionable `WARN` on the validated physical target;
- private data restored only from approved private sources;
- required security and boot controls manually reviewed where the verifier does not yet enforce them.

## What the public repository can restore

The repository can reconstruct reviewed desired state such as:

- required packages and repositories;
- GNOME configuration;
- GNOME extensions and version/source pins;
- repository-managed localization;
- selected network policy;
- selected security hardening;
- desktop integration and supported reproducible configuration.

It is **not** a complete user-data backup.

## What must remain private and be restored separately

Do not store the following in public Git:

- Btrfs streams or filesystem images;
- `/boot` or ESP backup archives;
- real filesystem UUIDs/PARTUUIDs;
- raw machine partition-table captures;
- private `fstab` captures containing identifying values;
- credentials and authentication tokens;
- SSH private keys;
- Wi-Fi secrets;
- browser profiles;
- password-manager vaults;
- Tailscale node identity;
- private signing material;
- precise/private location data;
- other personal machine state.

Private local configuration required by the repository must also be restored separately. For example, the real GNOME Weather location belongs in the gitignored `gnome/weather-locations.local.tsv`.

## Stop conditions

Pause the recovery instead of improvising if:

- backup checksums do not match;
- storage device identity is uncertain;
- the target disk contains unexpected data;
- the partition layout does not match the expected recovery model;
- a filesystem reports new I/O errors;
- the current hardware differs materially from the source system;
- UUID/boot relationships are ambiguous;
- Secure Boot or signing state cannot be reconciled safely.

A slower recovery with a verified target is preferable to a fast destructive mistake.

## Validation status and known limitation

The recovery model currently has two different levels of evidence:

### Repository rebuild

A clean-room Fedora restore has been exercised in a VM and the physical workstation has a clean accepted verifier baseline.

### Offline disaster-recovery set

The 2026-09-21 set was:

- created successfully after a clean physical verifier run;
- built from read-only root, home, and `/var/lib/machines` Btrfs snapshots;
- compressed with Zstandard;
- tested for compression-stream integrity;
- verified against its 21-entry SHA-256 manifest with every entry passing.

However, a complete **bare-metal restore onto an empty physical disk has not yet been exercised**.

Therefore the correct claim is:

> Backup creation and artifact integrity are validated; full physical bare-metal restore remains unexercised.

A future controlled spare-disk restore test would close that remaining disaster-recovery validation gap.

## Recovery decision summary

```text
                    severe failure
                          │
                          ▼
                    Fedora Live USB
                          │
                    classify failure
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
       clean rebuild             filesystem restore
            │                           │
     install Fedora               verify DR set
            │                           │
       clone repo                 identify target
            │                           │
   restore private data           rebuild storage
            │                           │
       install.sh                 receive Btrfs
            │                           │
     reboot/relogin               restore boot/EFI
            │                           │
            └─────────────┬─────────────┘
                          ▼
                    boot workstation
                          │
                          ▼
                    scripts/verify.sh
                          │
                          ▼
                  accept or investigate
```

## Related documents

- [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) — recovery architecture, retained generations, and backup contents.
- [RESTORE.md](RESTORE.md) — clean Fedora rebuild procedure.
- [CLEAN-ROOM-RESTORE-REPORT.md](CLEAN-ROOM-RESTORE-REPORT.md) — tested clean-room rebuild evidence.
- [../PROJECT-STATUS.md](../PROJECT-STATUS.md) — current workstation baseline and remaining engineering work.
