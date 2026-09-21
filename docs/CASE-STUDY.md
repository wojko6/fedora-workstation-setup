# Fedora Workstation Setup — Case Study

## Overview

This project provides a reproducible Fedora Workstation configuration pipeline.

The goal was to replace manual workstation setup with a validated restore process that installs packages, configures GNOME, applies security hardening, manages extensions, handles Polish localization, and verifies the final system state.

Target baseline:

- Fedora 44
- GNOME Shell 50.5
- Wayland session

Accepted baseline:
PASS=247 WARN=0 FAIL=0 SKIP=0


---

# Problem

Manual workstation configuration creates several long-term problems:

- configuration drift,
- inconsistent extension versions,
- missing localization,
- difficult recovery after reinstall,
- lack of verification.

The project solves this by introducing a declarative restore pipeline with automated validation.

---

# Architecture

The setup pipeline is divided into independent stages:
```text
install.sh
├── Package installation
├── External repositories
├── Flatpak applications
├── GNOME extensions
├── GNOME configuration restore
├── Localization pipeline
├── Desktop launchers
├── Network configuration
├── Firewall configuration
└── Security hardening
```

After installation, the system is validated by `scripts/verify.sh`.

---

# Engineering Highlights

## Reproducible GNOME Extensions

The project manages GNOME extensions as controlled components.

Validation includes:

- installation state,
- runtime activation,
- schema compilation,
- version verification.

Examples:

- Dhruva dock source pinning,
- ArcMenu gettext localization fix,
- extension inventory validation.

---

## Localization Engineering

The project contains version-specific Polish localization fixes.

Implemented solutions include:

- gettext catalog corrections,
- metadata localization,
- deterministic `.mo` generation,
- repository-based verification.

Validated components include:

- ArcMenu,
- Dhruva,
- Spotlight,
- Space Bar,
- Vitals,
- ddterm,
- Advanced Media Controller,
- Blur my Shell,
- Clipboard Indicator,
- Extension Manager,
- Helium,
- GNOME Tweaks,
- Papers / Nautilus,
- Plymouth offline updates,
- Ptyxis / libadwaita.

## ArcMenu gettext binding fix

ArcMenu v73 contained a Polish gettext catalog, but runtime translation loading required additional gettext domain handling.

The repository provides a version-pinned fix with automated verification:

- source fingerprint validation,
- portable patch application,
- runtime gettext verification.

Validated result:
PASS: ArcMenu v73 Polish gettext binding fix 

---

## Security Hardening

Implemented security improvements:

- LLMNR disabled,
- WSDD discovery disabled,
- kernel hardening settings,
- dedicated KDE Connect firewall zone,
- Secure Boot validation.

---

## Recovery Hardening

The restore pipeline validates the environment before making changes. The separate private offline DR layer was refreshed on 2026-09-21 after a clean physical verifier run; its compressed Btrfs/boot/EFI artifacts and 21-entry SHA-256 manifest passed full integrity verification.

Implemented:

- Fedora version preflight,
- GNOME version validation,
- fail-closed required stages,
- deterministic Wi-Fi power-save configuration.

Missing or invalid required stages stop execution instead of silently continuing.

---

# Validation Strategy

The project uses automated verification instead of manual confirmation.

Current final validation:
PASS=247 WARN=0 FAIL=0 SKIP=0

The verifier checks:

- installed packages,
- repositories,
- GNOME extensions,
- localization state,
- security settings,
- firewall configuration,
- recovery readiness.

---

# Lessons Learned

Key engineering lessons:

- configuration should be reproducible,
- every change should have validation,
- external dependencies should be pinned where possible,
- documentation is part of infrastructure quality.

---

# Current Status

Version:
v1.0-fedora44-gnome50-stable
The accepted baseline represents a fully validated Fedora Workstation environment.

## Automated verification

The project does not rely on manual confirmation only.  
Every important configuration change is followed by automated validation.

Validation entry point:
```text
Repository validation pipeline
├── scripts/verify.sh
│   ├── package validation
│   ├── repository validation
│   ├── GNOME extension validation
│   ├── localization verification
│   ├── security settings verification
│   ├── firewall configuration checks
│   └── recovery readiness checks
```

The final physical workstation verification completed on Fedora 44 / GNOME Shell 50.5 with:
```text
PASS=236
WARN=0
FAIL=0
SKIP=0
```


The verification pipeline checks:

- installed packages and external repositories,
- GNOME extension state and version consistency,
- localization overlays and gettext bindings,
- GNOME configuration state,
- firewall and network security settings,
- kernel security configuration,
- recovery and reproducibility requirements.

Key engineering principle:
```text
Configuration change
        |
        v
Automated verification
        |
        v
Accepted desired state
```

This makes the workstation rebuild process reproducible instead of dependent on manual setup history.
