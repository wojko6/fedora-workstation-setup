# Repository patches

This directory contains reviewed local patches that are required to reproduce the accepted workstation state and cannot be represented as ordinary settings or translation catalogs alone.

## GNOME extensions

`gnome-extensions/` contains version-specific source patches for reviewed GNOME extensions. Most are localization patches; `gnome-extensions/ding/desktopMenu-system-monitor.patch` is the audited DING v97 functional customization that adds the `Monitor systemu` desktop context-menu action.

## GNOME Keyring

`gnome-keyring/fix-gettext-i18n.patch` restores gettext/NLS initialization for the Fedora 44 GNOME Keyring 50.0 backport used by this workstation baseline.

Patches are intentionally narrow and version-sensitive. Install/build scripts must validate their expected target version or source context before applying them.
