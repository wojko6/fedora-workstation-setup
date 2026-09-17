#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESIRED_STATE="$ROOT_DIR/gnome/dhruva/dock-state.json"
STATE_DIR="$HOME/.config/dhruva@narkagni"
STATE_FILE="$STATE_DIR/dhruva-dock-items.json"

echo "=== DHRUVA DOCK CONFIG ==="

if [[ ! -f "$DESIRED_STATE" ]]; then
    echo "ERROR: missing repository Dhruva dock state: $DESIRED_STATE" >&2
    exit 1
fi

mkdir -p "$STATE_DIR"

python3 - "$DESIRED_STATE" "$STATE_FILE" <<'PY'
import json
import os
import sys
import tempfile
from pathlib import Path

desired_path = Path(sys.argv[1])
state_path = Path(sys.argv[2])

desired = json.loads(desired_path.read_text(encoding="utf-8"))

if not isinstance(desired, dict):
    raise SystemExit("ERROR: dock-state.json must contain a JSON object")

desired_order = desired.get("order")
desired_folders = desired.get("folders")

if not isinstance(desired_order, list) or not all(
    isinstance(item, str) for item in desired_order
):
    raise SystemExit("ERROR: dock-state.json 'order' must be an array of strings")

if not isinstance(desired_folders, list) or not all(
    isinstance(folder, dict) for folder in desired_folders
):
    raise SystemExit("ERROR: dock-state.json 'folders' must be an array of objects")

for folder in desired_folders:
    folder_id = folder.get("id")
    name = folder.get("name")
    icon = folder.get("icon")
    apps = folder.get("apps")

    if not isinstance(folder_id, str) or not folder_id:
        raise SystemExit("ERROR: every Dhruva folder requires a non-empty id")
    if not isinstance(name, str):
        raise SystemExit("ERROR: every Dhruva folder requires a name")
    if not isinstance(icon, str):
        raise SystemExit("ERROR: every Dhruva folder requires an icon")
    if not isinstance(apps, list) or not all(isinstance(app, str) for app in apps):
        raise SystemExit("ERROR: every Dhruva folder requires an apps array")

folder_keys = {f"folder:{folder['id']}" for folder in desired_folders}

for item in desired_order:
    if item.startswith("folder:") and item not in folder_keys:
        raise SystemExit(
            f"ERROR: dock order references undefined folder: {item}"
        )

if state_path.exists():
    state = json.loads(state_path.read_text(encoding="utf-8"))
    if not isinstance(state, dict):
        raise SystemExit("ERROR: existing Dhruva state must be a JSON object")
else:
    state = {}

# Dhruva is configured with independent-dock=false, so GNOME favorite-apps
# remains the authoritative pinned-app list. Keep 'apps' only as harmless
# compatibility state and never import private/local state into the repo.
state.setdefault("apps", [])

state["order"] = desired_order
state["folders"] = desired_folders

new_text = json.dumps(state, indent=2, ensure_ascii=False) + "\n"

if state_path.exists() and state_path.read_text(encoding="utf-8") == new_text:
    print("PASS: Dhruva dock state already matches repository")
    raise SystemExit(0)

fd, tmp_name = tempfile.mkstemp(
    prefix=".dhruva-dock-items.",
    suffix=".tmp",
    dir=state_path.parent,
)

try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(new_text)
        f.flush()
        os.fsync(f.fileno())

    os.replace(tmp_name, state_path)
finally:
    if os.path.exists(tmp_name):
        os.unlink(tmp_name)

print("PASS: Dhruva dock state synchronized with repository")
PY
