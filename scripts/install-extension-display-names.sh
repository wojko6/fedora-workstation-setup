#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT_DIR/scripts/extension-display-names.py" install
python3 "$ROOT_DIR/scripts/extension-display-names.py" verify

echo "PASS: selective Polish GNOME extension display names installed"
echo "Close and reopen GNOME Extensions / Extension Manager before visual acceptance."
