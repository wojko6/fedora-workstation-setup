#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$ROOT_DIR/gnome/enabled-extensions.txt"

command -v gnome-extensions >/dev/null 2>&1 || {
  echo "SKIP: gnome-extensions command is unavailable."
  exit 0
}

[[ -f "$LIST" ]] || {
  echo "ERROR: missing $LIST" >&2
  exit 1
}

echo "==> Checking required GNOME extensions"
missing=0
while IFS= read -r uuid; do
  [[ -z "$uuid" || "$uuid" == \#* ]] && continue
  if gnome-extensions info "$uuid" >/dev/null 2>&1; then
    printf 'OK:   %s\n' "$uuid"
  else
    printf 'MISS: %s\n' "$uuid"
    missing=$((missing + 1))
  fi
done < "$LIST"

if (( missing > 0 )); then
  printf 'INFO: %d extension(s) still need an installation source to be pinned in this repository.\n' "$missing"
else
  echo "All required extensions are installed."
fi
