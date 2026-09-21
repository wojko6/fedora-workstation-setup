#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / "install.sh"

text = INSTALL.read_text(encoding="utf-8")

required = [
    "if (( EUID == 0 )); then",
    "run install.sh as the desktop user, not root",
    "rpm-ostree status",
    "image-based Fedora (rpm-ostree) is not supported",
    "DBUS_SESSION_BUS_ADDRESS",
    "XDG_RUNTIME_DIR",
    '[[ ! -d "$XDG_RUNTIME_DIR" || ! -O "$XDG_RUNTIME_DIR" ]]',
]

for phrase in required:
    if phrase not in text:
        raise SystemExit(f"FAIL: installer preflight contract missing: {phrase}")

if INSTALL.stat().st_mode & 0o111 == 0:
    raise SystemExit("FAIL: install.sh is not executable")

print("PASS: installer rejects root execution")
print("PASS: installer rejects rpm-ostree/image-based Fedora")
print("PASS: installer requires a valid desktop user session")
print("PASS: install.sh is executable")
print("=== INSTALLER PREFLIGHT TESTS: PASS ===")
