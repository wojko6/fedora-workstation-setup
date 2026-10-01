#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

SETTINGS="$ROOT_DIR/gnome/settings.dconf"
INSTALLER="$ROOT_DIR/scripts/install-launchers.sh"

python3 - "$SETTINGS" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

header = "[org/gnome/shell/extensions/ding]"
parts = text.split(header)

if len(parts) != 2:
    raise SystemExit("FAIL: expected exactly one DING section")

section = parts[1].split("\n[", 1)[0]

expected = {
    "show-home": "true",
    "show-trash": "true",
    "show-volumes": "false",
    "show-network-volumes": "false",
}

values = {}

for line in section.splitlines():
    if "=" not in line:
        continue

    key, value = line.split("=", 1)

    if key in expected:
        values[key] = value

for key, wanted in expected.items():
    actual = values.get(key)

    if actual != wanted:
        raise SystemExit(
            f"FAIL: DING {key}: expected {wanted}, found {actual}"
        )

print("DING_RESTORE_POLICY=PASS")
PY

python3 - "$INSTALLER" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required = [
    "quarantine_unmanaged_desktop_entries",
    '"steam.desktop"',
    '"brave-origin.desktop"',
    '"com.nvidia.geforcenow.desktop"',
    '"asus-router.desktop"',
    'install_app_launcher \\\n    "$LAUNCHERS_DIR/counter-strike-2.desktop"',
]

for token in required:
    if token not in text:
        raise SystemExit(
            f"FAIL: desktop restore-policy token missing: {token}"
        )

if 'install_desktop_launcher \\\n    "$LAUNCHERS_DIR/counter-strike-2.desktop"' in text:
    raise SystemExit(
        "FAIL: Counter-Strike 2 must not be restored to physical Desktop"
    )

print("PHYSICAL_DESKTOP_RESTORE_POLICY=PASS")
PY

echo "PASS: restore desktop = ASUS SSH + Steam + Brave Origin + GeForce NOW + DING Home/Trash"
