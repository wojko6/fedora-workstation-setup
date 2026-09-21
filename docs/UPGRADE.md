# Fedora major-release upgrade runbook

This repository targets classic DNF/RPM Fedora Workstation. It does not support
rpm-ostree/image-based Fedora variants.

Use this procedure for an adjacent Fedora major upgrade only, for example
Fedora 44 -> 45. Do not promote a new Fedora/GNOME baseline directly on the
physical workstation.

## 1. Preconditions

Before planning the upgrade:

- the current physical baseline must pass `bash scripts/verify.sh` with zero
  `WARN`, zero `FAIL`, and zero `SKIP`;
- `main` must be clean and current;
- the latest disaster-recovery generation must be created and integrity-checked
  according to `docs/DISASTER-RECOVERY.md` and
  `docs/DISASTER-RECOVERY-RUNBOOK.md`;
- the target Fedora release must be generally available;
- the managed external repositories must publish usable metadata for the target
  release: RPM Fusion, Brave, `imput/helium`, and `tgerov/vpcs`;
- GNOME extensions and version-pinned localization patches must be reviewed for
  the target GNOME major before physical promotion.

Record the current state:

```bash
cd ~/Projekty/fedora-workstation-setup
git pull --ff-only
git status --short
git log -1 --oneline
bash scripts/check-static.sh
bash scripts/verify.sh
```

Do not continue if the physical verifier is not clean.

## 2. Fully update the current Fedora release

DNF5 requires the current system to be fully updated before a major upgrade.

```bash
sudo dnf5 --refresh upgrade
```

If the transaction updates the kernel, systemd, NVIDIA stack, or other
reboot-sensitive components, reboot before continuing. The current reboot hint
can be checked with:

```bash
dnf5 needs-restarting
```

After reboot, run `bash scripts/verify.sh` again and require the current
accepted baseline to remain clean.

## 3. Verify target-release repositories

Set the target release explicitly. Example:

```bash
TARGET=45
```

Check the repository set that is managed by this project:

```bash
for repo in \
  rpmfusion-free \
  rpmfusion-nonfree \
  brave-browser \
  'copr:copr.fedorainfracloud.org:imput:helium' \
  'copr:copr.fedorainfracloud.org:tgerov:vpcs'
do
  echo "=== $repo ==="
  dnf5 --releasever="$TARGET" repo info "$repo" || break
done
```

Do not force the upgrade through a repository that has no target-release
metadata. Revisit or temporarily disable a repository only after documenting
the impact on desired state.

## 4. VM qualification gate

Before changing the physical workstation:

1. clone or restore the Fedora VM test environment;
2. perform the same major-release upgrade in the VM;
3. review Fedora/GNOME changes, repository availability, GNOME extension
   compatibility, package replacements, and localization version pins;
4. update the repository on a dedicated branch for the new Fedora/GNOME
   baseline;
5. run `bash scripts/check-static.sh`;
6. run `bash scripts/verify.sh` in the VM.

The VM gate requires zero `WARN` and zero `FAIL`. Only already-documented
VM-specific `SKIP` results are acceptable.

Do not change `EXPECTED_FEDORA` or `EXPECTED_GNOME_MAJOR` on `main` until
the target release has passed this qualification step.

## 5. Download the physical system upgrade

On the physical workstation, first prepare the transaction without rebooting:

```bash
TARGET=45
sudo dnf5 system-upgrade download --releasever="$TARGET"
```

Review the transaction carefully. In particular, investigate unexpected package
removals, repository failures, NVIDIA/akmods changes, and packages supplied by
COPR/RPM Fusion.

Do not add `--allowerasing` automatically. If DNF5 cannot solve the
transaction, identify the conflicting package or repository first and make an
explicit decision.

## 6. Apply the offline upgrade

Only after the download/transaction review is clean:

```bash
sudo dnf5 system-upgrade reboot
```

DNF5 will reboot into its offline upgrade environment, apply the transaction,
and reboot back into the upgraded system.

## 7. Post-upgrade validation

After the first successful login:

```bash
cat /etc/fedora-release
gnome-shell --version
uname -r
dnf5 repolist --enabled
```

Then update the local checkout to the reviewed target-release branch and run:

```bash
bash scripts/check-static.sh
bash scripts/verify.sh
echo "VERIFY_RC=$?"
```

Do not run the old `install.sh` against a new Fedora/GNOME major while its
version guard is still pinned to the previous baseline.

The new physical baseline is accepted only after:

- required packages and repositories match desired state;
- intentionally absent packages remain absent;
- Secure Boot, NVIDIA module signing/MOK, SELinux, firewalld, and networking
  checks pass;
- every managed GNOME extension and localization pin has been reviewed for the
  new GNOME/application version;
- the full physical verifier reports zero `WARN`, zero `FAIL`, zero
  `SKIP`, and `VERIFY_RC=0`.

Only then update the documented accepted baseline and merge the new
`EXPECTED_FEDORA` / `EXPECTED_GNOME_MAJOR` values into `main`.

## 8. Failure handling

If the offline upgrade fails, inspect the latest DNF5 system-upgrade log:

```bash
dnf5 system-upgrade log --number=-1
```

Do not hide dependency problems with broad package removal or blind
`dnf autoremove`. If the installation is no longer trustworthy, use the
validated disaster-recovery path rather than improvising an in-place repair.

## References

- DNF5 system-upgrade documentation:
  https://dnf5.readthedocs.io/en/latest/commands/system-upgrade.8.html
- DNF5 offline transaction documentation:
  https://dnf5.readthedocs.io/en/latest/commands/offline.8.html
- DNF5 needs-restarting documentation:
  https://dnf5.readthedocs.io/en/latest/dnf5_plugins/needs_restarting.8.html
