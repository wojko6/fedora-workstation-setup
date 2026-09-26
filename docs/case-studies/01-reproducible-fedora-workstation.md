# Case Study 1 — Reproducible Fedora Workstation

## Executive summary

This project turns a personal Fedora workstation into a reproducible,
testable desired state rather than a collection of manual configuration steps.

The accepted physical baseline is:

```text
Fedora 44
GNOME Shell 50.5
Wayland

PASS=258
WARN=0
FAIL=0
SKIP=0
VERIFY_RC=0
```

The engineering goal is not only to make the workstation work after a clean
installation. The goal is to be able to explain what should exist, restore it
predictably, detect drift, reject unsupported states, and prove the final
result on the real machine.

## Problem

A manually maintained workstation tends to accumulate state that is difficult
to reconstruct:

- packages are installed over time without a single source of truth;
- GNOME settings drift;
- extension versions change independently;
- local fixes disappear after updates;
- firewall and security changes are easy to forget;
- recovery becomes dependent on memory;
- a successful boot does not prove that the workstation matches its intended
  configuration.

The project treats this as a configuration-management problem.

## Engineering approach

The repository separates desired state into explicit areas:

```text
packages
repositories
Flatpak applications
GNOME configuration
GNOME extensions
localization
network policy
firewall policy
security hardening
desktop integration
recovery documentation
```

The main restore path is orchestrated by `install.sh`, while
`scripts/verify.sh` independently checks the live system.

A key design rule is that the verifier is not just an installer success check.
The workstation is accepted only when the final live state matches the
repository after required session restarts or reboots.

## Fail-closed behavior

Where practical, the restore logic rejects states that cannot be explained by
the repository.

Examples include:

- Fedora/GNOME preflight checks;
- required package and repository checks;
- exact extension version verification;
- source/archive fingerprint validation;
- strict JSON metadata checks;
- extension-tree SHA-256 integrity locks;
- explicit firewall-zone validation;
- Secure Boot and NVIDIA signing checks;
- localization installers that accept only known pristine or exact
  repository-managed forms.

This prevents a version number alone from being treated as proof that the
installed component is correct.

## Drift detection

The project distinguishes between a deliberate desired-state change and
incidental live drift.

A representative example occurred during the 2026-09-26 localization cycle:

- Space Bar had drifted to a different CSS appearance;
- Dhruva had gained an extra `org.gnome.Settings.desktop` dock item;
- neither change was part of the intended feature work.

The repository values were restored instead of silently promoting the live
machine into the source of truth.

After reconciliation, the GNOME audit returned:

```text
PASS=78 WARN=0
```

## Extension integrity

All enabled user GNOME extensions are covered by deterministic whole-tree
integrity locks.

The verifier hashes the complete extension tree, including relative paths,
file modes, file sizes, file SHA-256 values and symlink targets. A same-version
extension with different content is therefore detected as drift.

At the current accepted baseline:

```text
22 enabled user-extension trees
all match the accepted integrity lock
```

This is stronger than checking only the extension's declared version.

## Physical and clean-room validation

The project uses two validation contexts:

- a clean Fedora virtual machine for restore-path testing;
- the physical Fedora workstation for final acceptance.

The physical system is the final source of evidence for hardware-dependent
behavior such as Wi-Fi, firewalld interface assignment, Secure Boot, NVIDIA,
monitor control and GNOME runtime behavior.

The current physical acceptance result is:

```text
PASS=258 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

## Recovery model

The public repository stores desired configuration rather than private user
data.

Credentials, private keys, browser profiles, Tailscale identity, private
location data and offline recovery artifacts remain outside Git.

The project also maintains a separate disaster-recovery design so that
configuration reconstruction and private-data recovery remain distinct
problems.

## Why this case study matters

This project demonstrates work across several areas at once:

- Linux administration;
- Bash and Python automation;
- configuration management;
- GNOME internals;
- package/repository management;
- network and firewall policy;
- security validation;
- CI/static checks;
- recovery engineering;
- technical documentation.

The main engineering lesson is that a workstation can be treated like a small
managed platform: every material change has a defined desired state, a restore
path and an acceptance test.

## Interview version

A concise way to describe the project:

> I built a reproducible Fedora workstation configuration rather than relying
> on manual setup. The repository manages packages, GNOME, extensions,
> localization, firewall policy and security settings. I added independent
> verification and deterministic extension-tree integrity checks so the same
> version is not automatically trusted if its contents drift. The current
> physical baseline passes 258 checks with zero warnings or failures.
