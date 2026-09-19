# Repository patches

This directory contains reviewed local patches that are required to reproduce the accepted workstation state and cannot be represented as ordinary settings or translation catalogs alone.

## GNOME extensions

`gnome-extensions/` contains version-specific source localization patches for extensions whose audited release lacks a usable upstream localization path.

## GNOME Keyring

`gnome-keyring/fix-gettext-i18n.patch` restores gettext/NLS initialization for the Fedora 44 GNOME Keyring 50.0 backport used by this workstation baseline.

Patches are intentionally narrow and version-sensitive. Install/build scripts must validate their expected target version or source context before applying them.
