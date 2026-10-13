# Incident report — 2026-10-13: NVIDIA 615 re-upgrade and failed suspend recovery

**Status:** operational recovery **PASS** for the observed display-off and one full `deep` suspend/resume cycle; long-run stability and KDE screen-lock recovery **NOT ACCEPTED**.  
**System:** physical Lenovo Legion 5 15ACH6H, Fedora 44, KDE Plasma 6.7.5 / Wayland, NVIDIA GeForce RTX 3060 Laptop GPU.  
**Related:** [2026-10-11 worklog](../WORKLOG-2026-10-11.md), [local Issue #51](https://github.com/wojko6/fedora-workstation-setup/issues/51), [KDE Bug #526934](https://bugs.kde.org/show_bug.cgi?id=526934).

This report records operator-observed physical-host actions. It does **not** promote KDE into the accepted, reproducible Fedora 44 / GNOME 50.5 desired state. Evidence is limited to the displayed command results and bounded journal excerpts. Sensitive raw journals and local RPM payloads are not committed.

## Executive finding

After a successful NVIDIA **615.71.09 → 610.57.04** rollback on 2026-10-11, the Fedora DNF5 update on **2026-10-13** (history transaction **118**, 267 changed packages) reinstalled NVIDIA **615.71.09** and introduced kernel **7.2.9-201**. No NVIDIA version lock existed at that point. The operator again observed a black screen / failure to recover normally after inactivity and a suspend attempt.

The October 13 journal captured an NVIDIA display warning followed by `PM: suspend entry (deep)`, without a matching successful suspend exit in the inspected previous-boot excerpt. Some non-graphics services continued to log; **complete kernel hang, resume failure timing and exclusive NVIDIA causation are not proven**.

The operator restored **all 12 NVIDIA 610.57.04 RPMs**, removed only the conflicting **615 kmod for 7.2.9-201**, selected kernel **7.2.9-200** (already containing an NVIDIA 610 kmod), and pinned ten NVIDIA package names using DNF5 `versionlock`. After reboot the graphics session worked, and both an ordinary screen-off/on test and one `deep` suspend/resume test succeeded.

**Attribution caveat:** the comparison changed **both** NVIDIA driver and kernel, so it does not isolate the exact faulty component. The separate 2026-10-11 repeatable `kscreenlocker_greet` SIGSEGV remains an unresolved KDE issue; the supplied October 13 test logs did not specifically audit that process.

## Observed incident timeline (2026-10-13 CEST)

| Time | Evidence | Interpretation |
| --- | --- | --- |
| ~09:29 | DNF history transaction 118 upgraded NVIDIA 610 → 615 and installed kernel 7.2.9-201 | Confirmed package change boundary; not itself proof of root cause |
| 11:37:56 | PowerDevil: `There are no outputs - creating placeholder screen` | Display-output transition |
| 11:37:58 | `systemd-logind`: `The system will suspend now!` | Sleep requested |
| 11:38:01 | `nvidia-modeset`: `WARNING: GPU:0: Lost display notification ...; continuing.` | Relevant GPU warning; not a definitive error classification |
| 11:38:04 | KWin delay inhibitor timed out; NVIDIA suspend service skipped by condition; kernel: `PM: suspend entry (deep)` | Suspend transition started |
| 11:38–11:40 | Selected services logged network failures and other events; inspected excerpt lacks a successful `PM: suspend exit` | Inconclusive failure stage; network failures follow sleep/network-down state and do not prove network caused GPU problem |
| 11:40:50 | New boot appears in `journalctl --list-boots` | Restart/new boot confirmed; restart method not inferred |

### NVIDIA sleep configuration before rollback

- `/sys/power/mem_sleep`: `s2idle [deep]` (deep selected).
- `UseKernelSuspendNotifiers: 1`; `PreserveVideoMemoryAllocations: 2`; `EnableS0ixPowerManagement: 0`.
- `nvidia-suspend.service` and `nvidia-resume.service` each have an `ExecCondition` requiring `UseKernelSuspendNotifiers: 0`. Skipping the service with value 1 is **expected** and must not be treated as the cause.
- A separate 2026-10-11 screen-lock crash at `PlasmaQuick::SharedQmlEngine::rootObject()` is still open under [KDE Bug #526934](https://bugs.kde.org/show_bug.cgi?id=526934).

## Preflight and rollback

### Evidence and transaction planning

1. Operator archive contained **12** local NVIDIA **610.57.04-1.fc44** RPMs, including akmod, common user-space, CUDA, 32-bit/64-bit libraries, power and kmodsrc.
2. All twelve files returned `rpm -K: skróty podpisy OK` (digests/signature check passed). During the later local `dnf5 downgrade`, DNF warned that its **own** OpenPGP check was skipped for `@commandline` RPMs; do not confuse that with the preceding RPM verification.
3. Initial `sudo dnf5 --assumeno downgrade "$D"/*.rpm` rejected the transaction because the installed kernel-specific **615** kmod for **7.2.9-201** required `nvidia-kmod-common >= 3:615.71.09`.
4. `sudo dnf5 --assumeno downgrade --allowerasing "$D"/*.rpm` then proposed **12 NVIDIA downgrades and removal of exactly one conflicting kmod**. It proposed no unrelated KDE or workstation package removals. Do **not** substitute `--skip-broken` or undo DNF transaction 118 wholesale.
5. `modinfo -k 7.2.9-200.fc44.x86_64 -F version nvidia` reported **610.57.04**; for 7.2.9-201 it had reported **615.71.09**. All three kernel-core packages 7.2.8-200, 7.2.9-200, 7.2.9-201 were retained.

### Changes applied by operator

- Switched default GRUB kernel from 7.2.9-201 to **7.2.9-200** using `grubby --set-default`; verified via `grubby --default-kernel`.
- Executed the reviewed **12-package** `dnf5 downgrade --allowerasing` from the local signed RPM set; the transaction finished `Ukończono!`. The only extra package removed was `kmod-nvidia-7.2.9-201...615.71.09`.
- Added **10 DNF5 versionlock package rules**, each displaying `evr = 3:610.57.04-1.fc44`:
  `akmod-nvidia`, `nvidia-modprobe`, `nvidia-persistenced`, `nvidia-settings`, `xorg-x11-drv-nvidia`, `xorg-x11-drv-nvidia-cuda`, `xorg-x11-drv-nvidia-cuda-libs`, `xorg-x11-drv-nvidia-kmodsrc`, `xorg-x11-drv-nvidia-libs`, `xorg-x11-drv-nvidia-power`.
- Confirmed `kmod-nvidia-7.2.9-200...610.57.04`, `modinfo` module version/vermagic, and existing `/boot/initramfs-7.2.9-200.fc44.x86_64.img` (153 MB); no 7.2.9-201 NVIDIA 610 module build was claimed.
- Rebooted into **kernel 7.2.9-200**. `nvidia-smi` and `/proc/driver/nvidia/version` both reported **610.57.04**; `KDE / wayland` was active; `systemctl --failed` and user-level equivalent reported zero failed units.
- Set DNF5 `installonly_limit=5` (was 3) with `protect_running_kernel=1` retained. Afterward `/boot` was **2.0 GB total / 831 MB used / 997 MB available**; EFI was separately 599 MB total / 579 MB available.

### Recovery commands — reference only, not an unattended runbook

~~~bash
# Confirm available modules and intended boot target before any downgrade.
modinfo -k 7.2.9-200.fc44.x86_64 -F version nvidia
sudo grubby --info=/boot/vmlinuz-7.2.9-200.fc44.x86_64

# The operator selected the known-working kernel:
sudo grubby --set-default /boot/vmlinuz-7.2.9-200.fc44.x86_64

# Review BEFORE applying changes; local RPMs must already be verified.
D="$HOME/Pobrane/nvidia-610.57.04-rpmfusion"
sudo dnf5 --assumeno downgrade --allowerasing "$D"/*.rpm

# Actual change was executed only after that transaction plan matched.
sudo dnf5 downgrade --allowerasing "$D"/*.rpm
~~~

These commands are **historical, environment-specific evidence**. A future recovery requires a fresh package/dependency simulation, the correct bootable and signed kmod, a recovery path and operator review. The 2026-10-11 automated rollback script marked `.BROKEN` remains unapproved. No secrets, local certificates, signatures or binary RPMs are stored in this repository.

## Verification after recovery

| Gate | Observation | Result |
| --- | --- | --- |
| Boot and graphics | `uname -r=7.2.9-200.fc44.x86_64`; NVIDIA 610.57.04; KDE Wayland active | **PASS** |
| Failed system/user units | `0 loaded units listed` for each | **PASS at observation time** |
| Ordinary screen-off/on | Screen powered off by KDE inactivity timer and display recovered with user input | **PASS (one manual test)** |
| Full deep suspend | `PM: suspend entry (deep)` **12:25:57** → device suspend/resume **12:26:38** → `PM: suspend exit` **12:26:40** | **PASS (one manual test)** |
| systemd sleep | `System returned from sleep operation 'suspend'`; `systemd-suspend.service: Deactivated successfully` | **PASS** |
| Kernel NVIDIA errors | No GPU-specific `Xid` or `NVRM` failure in the operator's filtered validation output | **No matching error in shown excerpt; not a full journal audit** |
| DNF package lifecycle | Ten 610 version locks listed; DNF5 installonly_limit=5 | **PASS** |
| KDE lock greeter | No targeted October 13 greeter crash journal/coredump review supplied | **UNVERIFIED; Bug #526934 remains open** |
| Secure Boot signing (Oct 13) | Existing Oct 11 signing-chain evidence; not independently retested here | **NOT RETESTED** |
| Long-run / multi-cycle stability | Single post-fix deep cycle and a screen-off/on test | **PENDING** |

A systemd message noted `SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=0`; it did not prevent this successful wake. This log does not establish that all future suspend variants or external-monitor transitions are reliable.

## Safeguards, remaining risks and follow-up

1. **Keep driver version lock** while NVIDIA 615.71.09 is unqualified. Before any future NVIDIA upgrade, evaluate proposed driver/kmod, Mesa, kernel and display-stack changes together; require a rollback and controlled resume tests. A version lock is not proof that NVIDIA 610 will build against every future kernel.
2. **Keep kernel 7.2.9-200 bootable** for recovery. The increased DNF5 `installonly_limit=5` only delays kernel eviction; it is **not** indefinite pinning. Inspect `df -h /boot`, retained kernel packages, modules, and default boot entry before maintenance. Preserve a practical free-space margin.
3. **Do not close KDE Bug #526934 / local Issue #51 yet.** The repeatable Oct 11 `kscreenlocker_greet` 2/2 SIGSEGV was not independently disproven on Oct 13. Obtain targeted screen-lock journal evidence and repeat controlled tests before claiming resolution.
4. **Do not promote KDE as accepted desired state.** GNOME 50.5 remains canonical; session switching / clean-room restore / full verifier gates for KDE are still open under [Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12).
5. **Retain recovery artifacts outside Git.** The RPM archive, private journal excerpts, local backups and signing material remain operator-managed; public documentation deliberately omits account, device, network and credential data.

**Disposition (13 Oct 2026):** recovery and one post-reboot deep resume are verified; **root cause and sustained KDE power-management acceptance remain open**.
