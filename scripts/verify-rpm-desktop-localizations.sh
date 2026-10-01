#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

python3 \
  "$ROOT_DIR/scripts/desktop-entry-localization.py" \
  --manifest "$ROOT_DIR/desktop/menu-localization-rpm.json" \
  --mode verify
