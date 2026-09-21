# Fedora major-upgrade runbook

This runbook covers promotion of this workstation from one supported Fedora release to the next while preserving the repository's fail-closed desired-state model.

It applies to classic DNF/RPM Fedora Workstation only. Image-based Fedora variants are outside this repository's supported restore path.

## Policy

A Fedora major upgrade is not accepted merely because the operating system boots.

The target release becomes the new project baseline only after:

- the current release is clean before upgrade;
- the target Fedora release is stable and the required third-party repositories are available for it;
- repository changes for the new Fedora/GNOME baseline pass static CI;
- a clean-room VM restore of the target baseline is completed;
- the physical workstation completes the full verifier with zero WARN, zero FAIL, and zero SKIP;
- version-pinned GNOME extensions and localization patches are re-audited where their upstream version changed.

Do not change the documented accepted baseline before the physical acceptance run.

## 1. Pre-upgrade gate

Start from the canonical checkout:

```bash
cd ~/Projekty/fedora-workstation-setup
git pull --ff-only
git status --short
bash scripts/verify.sh
echo "VERIFY_RC=$?"
```

Do not continue unless the current physical baseline is clean.

Bring the current Fedora release fully up to date first:

```bash
sudo dnf upgrade --refresh
sudo reboot
```

After reboot, rerun `bash scripts/verify.sh`.

Before the major upgrade, confirm that the required external package sources have a target-release path:

- RPM Fusion Free and Nonfree;
- Brave;
- COPR `imput/helium`;
- COPR `tgerov/vpcs`.

The VPCS COPR must remain restricted to `includepkgs=vpcs`.

Also confirm that the latest offline disaster-recovery generation is available and integrity-verified. A major-version downgrade is not the rollback plan; recovery means restoring the known-good generation or performing a clean rebuild.

## 2. Prepare the target baseline in Git

Create a dedicated upgrade branch before touching the physical workstation.

Review at minimum:

- `EXPECTED_FEDORA` in `install.sh`;
- the supported GNOME major;
- required and intentionally absent RPM manifests;
- external repository bootstrap and trust settings;
- NVIDIA/akmods/Secure Boot handling;
- every version-pinned GNOME extension;
- every version-pinned localization installer/verifier;
- package names retired, renamed, or moved between repositories.

Do not relax a failing version pin just to make the verifier green. Re-audit the affected component and then update the pin or patch deliberately.

Run:

```bash
bash scripts/check-static.sh
```

and require the GitHub Actions Fedora and generic validation jobs to pass.

## 3. Clean-room gate

Before promoting the branch to the physical workstation, test a clean Fedora target-release VM.

The clean-room test should cover:

1. repository bootstrap;
2. RPM and Flatpak installation;
3. GNOME extension installation and activation;
4. localization stages;
5. security/network configuration applicable to the VM;
6. logout/login or reboot where required;
7. the complete verifier.

Environment-specific hardware SKIPs are acceptable only when they are explicitly classified as VM-only exclusions. Unexpected WARN or FAIL results are not accepted.

Record the clean-room result without rewriting historical Fedora 44 checkpoints.

## 4. Physical Fedora upgrade

Fedora's supported command-line path uses DNF system-upgrade. For the next release, set the reviewed target number explicitly, for example:

```bash
TARGET=45
sudo dnf system-upgrade download --releasever="$TARGET"
```

Read the proposed transaction before proceeding. Do not add `--allowerasing` automatically. If DNF requests it because of third-party packages, identify the exact conflicting packages and decide on them individually.

When the download transaction is acceptable:

```bash
sudo dnf system-upgrade reboot
```

This reboots immediately into the offline upgrade environment.

## 5. First boot on the target release

Before changing desired-state documentation, collect the actual platform state:

```bash
cat /etc/fedora-release
gnome-shell --version
uname -r
mokutil --sb-state
modinfo -F signer nvidia
modinfo -F sig_hashalgo nvidia
dnf repolist --enabled
```

Confirm that:

- Secure Boot is still enabled;
- the NVIDIA module loads and remains signed;
- required external repositories are enabled for the new release;
- the VPCS COPR still has `Include packages: vpcs`;
- Tailscale and the trusted-Wi-Fi firewalld policy remain operational.

Review any `.rpmnew` or `.rpmsave` files before merging configuration changes. Do not run blind `dnf autoremove`.

## 6. Apply the reviewed target-baseline branch

Use the branch prepared and tested for the new Fedora/GNOME version. Do not run the old Fedora 44 installer against an unsupported target.

After applying any reviewed target-specific changes, restart the GNOME session or reboot and run:

```bash
bash scripts/verify.sh
echo "VERIFY_RC=$?"
```

Acceptance requires:

```text
WARN=0
FAIL=0
SKIP=0
VERIFY_RC=0
```

The PASS total is observed, not predicted.

## 7. Promote the new baseline

Only after clean VM validation and the successful physical verifier:

- merge the target-baseline branch;
- update Fedora/GNOME versions in public documentation;
- record the new physical PASS aggregate;
- update the clean-room report with a new target-release section instead of overwriting older results;
- update the private worklog;
- create and verify a new disaster-recovery generation.

Historical Fedora 44 results remain historical evidence and must not be rewritten to the new aggregate.

## Recovery rule

If the physical major upgrade breaks boot, Secure Boot/NVIDIA, networking, storage, or the repository cannot reach a zero-warning/zero-failure state in a controlled way, stop baseline promotion.

Preferred recovery order:

1. boot a known-good older kernel if the fault is kernel/module-specific;
2. use the validated disaster-recovery generation when system state is no longer trustworthy;
3. perform a clean target-release rebuild through the repository if recovery is preferable to repairing the upgraded installation.

Do not treat `dnf distro-sync --allowerasing`, mass package removal, or `dnf autoremove` as automatic recovery actions.

## Fedora reference

The command-line major-upgrade process follows Fedora's DNF system-upgrade guidance: fully update the current release first, download the target release transaction with `dnf system-upgrade download --releasever=N`, review dependency removals carefully, and then trigger the offline upgrade with `dnf system-upgrade reboot`.
