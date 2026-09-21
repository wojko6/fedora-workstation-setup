#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="ding@rastersoft.com"
EXPECTED_VERSION="97"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET="$EXT_DIR/app/desktopMenu.js"
PATCH_FILE="$ROOT_DIR/patches/gnome-extensions/ding/desktopMenu-system-monitor.patch"
DESKTOP_FILE="/usr/share/applications/org.gnome.SystemMonitor.desktop"

for path in "$TARGET" "$PATCH_FILE" "$DESKTOP_FILE"; do
  [[ -f "$path" ]] || {
    echo "FAIL: required DING System Monitor verification file missing: $path" >&2
    exit 1
  }
done

version="$(
  python3 - "$EXT_DIR/metadata.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
version = metadata.get("version")
if isinstance(version, bool) or not isinstance(version, (int, str)):
    raise SystemExit(1)
print(version)
PY
)"

[[ "$version" == "$EXPECTED_VERSION" ]] || {
  echo "FAIL: DING runtime version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
  exit 1
}

python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

action = """        this._addNewAction('open-system-monitor', null, () => {
            const desktopFile = GioUnix.DesktopAppInfo.new('org.gnome.SystemMonitor.desktop');
            if (desktopFile) {
                const context = Gdk.Display.get_default().get_app_launch_context();
                context.set_timestamp(Gdk.CURRENT_TIME);
                desktopFile.launch([], context);
            }
        });
"""

menu = """        this._newMenuElement('Monitor systemu', "open-system-monitor", section);
"""

if text.count(action) != 1:
    raise SystemExit("FAIL: DING System Monitor action block missing, duplicated, or drifted")
if text.count(menu) != 1:
    raise SystemExit("FAIL: DING System Monitor menu entry missing, duplicated, or drifted")
if text.count("org.gnome.SystemMonitor.desktop") != 1:
    raise SystemExit("FAIL: unexpected GNOME System Monitor desktop-file reference count")
PY

echo "PASS: DING v97 System Monitor desktop-menu integration matches repository"
