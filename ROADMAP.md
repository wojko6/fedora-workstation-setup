# Fedora Workstation Engineering Roadmap

**Status:** active roadmap  
**Current accepted baseline:** Fedora 44 / GNOME Shell 50.5 / Wayland  
**Umbrella tracker:** [Issue #17](https://github.com/wojko6/fedora-workstation-setup/issues/17)

This document is the canonical technical roadmap for the Fedora workstation
project.

The GitHub Project tracks execution state. Individual GitHub issues contain
detailed acceptance criteria. PROJECT-STATUS.md remains the source of truth for
what is already physically accepted.

The roadmap must never blur planned work into the accepted desired state.

## Current accepted baseline

~~~text
Fedora 44
GNOME Shell 50.5
Wayland

PASS=256
WARN=0
FAIL=0
SKIP=0
VERIFY_RC=0
~~~

Future work must preserve this baseline unless a new one is deliberately
promoted through the documented validation process.

## Roadmap principles

1. Preserve the accepted GNOME workstation before adding new features.
2. Prefer non-mutating preflight and clean-room validation before physical
   changes.
3. Keep desired-state changes fail-closed where practical.
4. Separate recurring lifecycle maintenance from one-time feature work.
5. Require rollback or a disposable test environment for risky changes.
6. Re-run dedicated checks plus the full verifier after material desired-state
   changes.
7. Do not promote a Fedora/GNOME baseline based only on a successful update,
   boot or package transaction.
8. Keep machine-specific data, credentials and private recovery material outside
   public Git.

## NOW — hardening and engineering maturity

These items strengthen the existing accepted baseline without deliberately
changing the desktop environment.

### #27 — GNOME extension archive provenance

[Harden GitHub-sourced GNOME extensions with archive SHA-256 verification](https://github.com/wojko6/fedora-workstation-setup/issues/27)

- add audited SHA-256 verification for GitHub-sourced extension archives;
- fail closed on missing or incorrect archive digests;
- preserve exact commit, UUID, runtime-version and final-tree integrity checks.

### #28 — authoritative SELinux AVC verification

[Improve SELinux AVC verification using the audit subsystem](https://github.com/wojko6/fedora-workstation-setup/issues/28)

- prefer ausearch / the audit subsystem for current-boot AVC and USER_AVC evidence;
- distinguish unavailable evidence from a verified zero-denial result;
- keep SELinux policy itself unchanged.

### #29 — reproducible Flatpak locking

[Add reproducible Flatpak locking and controlled version promotion](https://github.com/wojko6/fedora-workstation-setup/issues/29)

- lock repository-managed Flatpaks by origin, branch and accepted OSTree commit;
- detect Flatpak drift;
- make upgrades deliberate promotion events rather than implicit restore-time
  changes.

### #30 — independent history-aware secret scanning

[Strengthen secret scanning with an independent history-aware scanner](https://github.com/wojko6/fedora-workstation-setup/issues/30)

- retain the project-owned scanner;
- add a second pinned independent scanner;
- scan complete reachable Git history;
- fail closed without printing secret values into CI logs.

### #31 — installer preflight / check mode

[Add installer preflight/check mode before applying workstation mutations](https://github.com/wojko6/fedora-workstation-setup/issues/31)

Target flow:

~~~text
check
  ↓
operator-readable plan
  ↓
apply
  ↓
session restart / reboot where required
  ↓
verify
~~~

The first objective is to detect common late-stage failures before the first
mutation and reduce partial convergence, not to invent a universal transaction
engine.

### #33 — stricter CI and static-analysis gates

[Harden CI and static-analysis gates](https://github.com/wojko6/fedora-workstation-setup/issues/33)

- raise ShellCheck from error-only to at least warning-level enforcement after
  reviewing current findings;
- make the Fedora CI environment more reproducible;
- keep workflow dependencies deliberately pinned and maintainable.

## CONTINUOUS — lifecycle maintenance

### #14 — package, extension and localization pins

[Maintain package, GNOME extension and localization pins](https://github.com/wojko6/fedora-workstation-setup/issues/14)

This issue is intentionally recurring rather than a one-time project.

~~~text
upstream change detected
        ↓
compatibility / source review
        ↓
update candidate pins
        ↓
dedicated localization / integrity checks
        ↓
physical validation
        ↓
promote accepted desired state
~~~

Do not change versions or hashes merely to silence drift detection.

## NEXT — major validation milestones

These items have higher operational impact and should follow the near-term
hardening work or begin only when their prerequisites are available.

### #32 — refresh disaster recovery and exercise bare-metal restore

[Refresh disaster-recovery generation and exercise a controlled bare-metal restore](https://github.com/wojko6/fedora-workstation-setup/issues/32)

- create a fresh private DR generation from the current accepted baseline;
- verify archive and stream integrity;
- rehearse a restore onto a spare or secondary disk;
- validate EFI/boot, Btrfs, repository reconciliation, Secure Boot/NVIDIA,
  networking and the full verifier on the restored host.

A destructive restore must never target the only known-good system disk.

### #13 — Fedora major-upgrade readiness

[Maintain Fedora major-upgrade readiness and validation workflow](https://github.com/wojko6/fedora-workstation-setup/issues/13)

~~~text
target-release repository review
        ↓
GNOME extension / localization compatibility review
        ↓
clean-room upgrade / rebuild
        ↓
remediation
        ↓
physical upgrade
        ↓
full verifier
        ↓
new baseline promotion
        ↓
DR refresh
~~~

The detailed operational procedure remains in docs/UPGRADE.md.

### #12 — reproducible GNOME + KDE Plasma coexistence

[Design reproducible GNOME + KDE Plasma desktop environments](https://github.com/wojko6/fedora-workstation-setup/issues/12)

GNOME remains canonical. KDE Plasma is an optional future session, not a
replacement baseline.

The first KDE phase must avoid changing several major variables at once.
Promotion requires validation of:

- GNOME -> KDE -> GNOME session switching;
- rollback to the accepted GNOME state;
- XDG portals;
- MIME/default applications;
- keyring/KWallet interaction;
- autostart behavior;
- Wayland;
- Tailscale/networking;
- audio and Bluetooth;
- removable storage;
- reproducible KDE configuration capture/restore;
- full repository verification.

## LATER / CONDITIONAL

### #16 — LUKS during a controlled reinstall or restore

[Plan LUKS introduction for a future controlled reinstall or restore](https://github.com/wojko6/fedora-workstation-setup/issues/16)

The current accepted Btrfs installation is not claimed to be fully encrypted.

Preferred path:

~~~text
clean-room design
  ↓
LUKS + Btrfs layout validation
  ↓
recovery-key / backup design
  ↓
boot + initramfs + Secure Boot/NVIDIA validation
  ↓
future scheduled reinstall / restore
~~~

Risky in-place conversion remains out of scope.

### #15 — VSCodium localization scope decision

[Evaluate whether VSCodium localization should enter project scope](https://github.com/wojko6/fedora-workstation-setup/issues/15)

This is an investigation, not a commitment to maintain another localization
layer. Remaining intentionally deferred is an acceptable outcome if the
maintenance cost or ownership boundaries do not justify repository-managed
localization.

## Relationship to broader engineering ideas

Longer-horizon concepts such as a workstation-wide drift detector, upgrade
readiness engine, Btrfs safe-change workflow, automated disaster-recovery drills
and a health dashboard are tracked in the separate engineering-ideas incubator.

They should be promoted into this repository only when they become bounded
implementation work for the Fedora workstation.

## Promotion gates

A roadmap item enters the accepted desired state only when the relevant gates
pass.

### Repository gate

- static validation clean;
- repository consistency clean;
- security fixtures clean;
- no unresolved secret/publication findings.

### Feature-specific gate

- the issue's dedicated acceptance criteria pass;
- rollback is tested where relevant;
- version/source/provenance expectations are explicit.

### Clean-room gate

Required when the change materially affects restore behavior, Fedora/GNOME major
version, boot/storage layout, desktop-environment architecture or other
high-impact recovery assumptions.

### Physical acceptance gate

After any required session restart or reboot:

~~~bash
bash scripts/verify.sh
~~~

The accepted physical target must return:

~~~text
WARN=0
FAIL=0
VERIFY_RC=0
~~~

The absolute PASS count may legitimately change as the verifier evolves.

## Queue discipline

Do not implement every open issue simultaneously.

~~~text
1-2 active implementation-heavy items
        ↓
validation
        ↓
accepted checkpoint
        ↓
next item
~~~

Recurring maintenance such as Issue #14 may continue alongside one bounded
implementation item.

## Tracking

- [Issue #17 — umbrella roadmap tracker](https://github.com/wojko6/fedora-workstation-setup/issues/17)
- [PROJECT-STATUS.md](PROJECT-STATUS.md) — currently accepted state
- [docs/UPGRADE.md](docs/UPGRADE.md) — major Fedora upgrade lifecycle
- [docs/DISASTER-RECOVERY.md](docs/DISASTER-RECOVERY.md) — DR architecture
- [docs/DISASTER-RECOVERY-RUNBOOK.md](docs/DISASTER-RECOVERY-RUNBOOK.md) — total-failure recovery
- [docs/LOCALIZATION-STATUS.md](docs/LOCALIZATION-STATUS.md) — localization scope
