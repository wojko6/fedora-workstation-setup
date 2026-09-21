#!/usr/bin/env python3
from __future__ import annotations

import stat
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"
LAUNCHER_INSTALLER = ROOT / "scripts" / "install-launchers.sh"

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

print("PASS: installer non-root/session/rpm-ostree preflight contracts present")
print("PASS: ASUS launcher config remains data-only")
print("=== INSTALLER PREFLIGHT TESTS: PASS ===")
