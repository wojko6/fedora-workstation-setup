#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/packages/rpm.txt"

mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")

if (( ${#packages[@]} == 0 )); then
  echo "RPM manifest is not populated yet; skipping."
  exit 0
fi

sudo dnf install -y "${packages[@]}"
