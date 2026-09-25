#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="ding@rastersoft.com"
EXPECTED_VERSION="97"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET="$EXT_DIR/app/desktopMenu.js"
PATCH_FILE="$ROOT_DIR/patches/gnome-extensions/ding/desktopMenu-system-monitor.patch"
DESKTOP_FILE="/usr/share/applications/org.gnome.SystemMonitor.desktop"
VERIFIER="$ROOT_DIR/scripts/verify-ding-system-monitor-menu.sh"

for cmd in python3 patch; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "FAIL: required command not found: $cmd" >&2
    exit 1
  }
done

for path in "$TARGET" "$PATCH_FILE" "$DESKTOP_FILE" "$VERIFIER"; do
  [[ -f "$path" ]] || {
    echo "FAIL: required DING system-monitor integration file missing: $path" >&2
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

if [[ "$version" != "$EXPECTED_VERSION" ]]; then
  echo "FAIL: DING runtime version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
  exit 1
fi

action_count="$(grep -Fc "'open-system-monitor'" "$TARGET" || true)"
desktop_count="$(grep -Fc "org.gnome.SystemMonitor.desktop" "$TARGET" || true)"
menu_count="$(grep -Fc "this._newMenuElement(_('System Monitor'), \"open-system-monitor\", section);" "$TARGET" || true)"

if [[ "$action_count" == "1" && "$desktop_count" == "1" && "$menu_count" == "1" ]]; then
  bash "$VERIFIER"
  echo "PASS: DING System Monitor desktop-menu integration already installed"
  exit 0
fi

legacy_menu_count="$(grep -Fc "'Monitor systemu'" "$TARGET" || true)"

if (( action_count > 0 || desktop_count > 0 || menu_count > 0 || legacy_menu_count > 0 )); then
  echo "FAIL: partial DING System Monitor customization detected; refusing to patch" >&2
  exit 1
fi

if ! patch --dry-run --batch --forward -p1 -d "$EXT_DIR" <"$PATCH_FILE" >/dev/null; then
  echo "FAIL: DING System Monitor patch is incompatible with installed DING v$EXPECTED_VERSION" >&2
  exit 1
fi

patch --batch --forward -p1 -d "$EXT_DIR" <"$PATCH_FILE" >/dev/null

bash "$VERIFIER"
echo "PASS: DING System Monitor desktop-menu integration installed"
echo "Reload DING or sign out/in before visually validating the new menu item."
