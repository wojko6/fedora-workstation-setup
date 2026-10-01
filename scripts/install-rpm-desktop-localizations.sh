#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

python3 \
  "$ROOT_DIR/scripts/desktop-entry-localization.py" \
  --manifest "$ROOT_DIR/desktop/menu-localization-rpm.json" \
  --mode install

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database \
    "$HOME/.local/share/applications" \
    >/dev/null 2>&1 || true
fi

echo "PASS: RPM application-menu Polish localization installed"
