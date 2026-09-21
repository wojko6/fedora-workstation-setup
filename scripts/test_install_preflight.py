#!/usr/bin/env python3
from __future__ import annotations

import stat
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"
LAUNCHER_INSTALLER = ROOT / "scripts" / "install-launchers.sh"
PACKAGE_INSTALLER = ROOT / "scripts" / "install-packages.sh"
FLATPAK_INSTALLER = ROOT / "scripts" / "install-flatpaks.sh"
VERIFIER = ROOT / "scripts" / "verify.sh"

installer = INSTALLER.read_text(encoding="utf-8")

required_installer_contracts = [
    "if (( EUID == 0 )); then",
    "DBUS_SESSION_BUS_ADDRESS",
    "XDG_RUNTIME_DIR",
    "rpm-ostree status",
    'EXPECTED_FEDORA="44"',
    'EXPECTED_GNOME_MAJOR="50"',
]

for phrase in required_installer_contracts:
    if phrase not in installer:
        raise SystemExit(f"FAIL: installer preflight contract missing: {phrase}")

if not INSTALLER.stat().st_mode & stat.S_IXUSR:
    raise SystemExit("FAIL: install.sh is not executable by its owner")

launcher_installer = LAUNCHER_INSTALLER.read_text(encoding="utf-8")
if 'source "$ASUS_CONF"' in launcher_installer:
    raise SystemExit("FAIL: private ASUS launcher config is still sourced as shell code")

for phrase in [
    "render-asus-launcher.py",
    "--check-key-file",
    "desktop-file-validate",
]:
    if phrase not in launcher_installer:
        raise SystemExit(f"FAIL: ASUS launcher hardening contract missing: {phrase}")

package_installer = PACKAGE_INSTALLER.read_text(encoding="utf-8")
for phrase in [
    'for manifest in "$MANIFEST" "$ABSENT_MANIFEST"; do',
    'if [[ ! -r "$manifest" ]]; then',
    "ERROR: required package manifest missing or unreadable:",
    "ERROR: required RPM manifest is empty:",
]:
    if phrase not in package_installer:
        raise SystemExit(f"FAIL: package-manifest fail-closed contract missing: {phrase}")

if "RPM manifest is not populated yet; skipping." in package_installer:
    raise SystemExit("FAIL: empty required RPM manifest can still be accepted as SKIP")

flatpak_installer = FLATPAK_INSTALLER.read_text(encoding="utf-8")
for phrase in [
    "flatpak remotes --system --columns=name",
    "sudo flatpak remote-add --system --if-not-exists flathub",
    'sudo flatpak install --system -y flathub "$app"',
]:
    if phrase not in flatpak_installer:
        raise SystemExit(f"FAIL: system Flatpak install contract missing: {phrase}")

verifier = VERIFIER.read_text(encoding="utf-8")
for phrase in [
    "flatpak remotes --system --columns=name",
    'flatpak --system info "$app"',
]:
    if phrase not in verifier:
        raise SystemExit(f"FAIL: system Flatpak verification contract missing: {phrase}")

print("PASS: installer non-root/session/rpm-ostree preflight contracts present")
print("PASS: ASUS launcher config remains data-only")
print("PASS: RPM desired-state manifests fail closed before package mutation")
print("PASS: Flatpak desired state is consistently system-scoped")
print("=== INSTALLER PREFLIGHT TESTS: PASS ===")
