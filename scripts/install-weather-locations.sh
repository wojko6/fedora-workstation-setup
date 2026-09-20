#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANAGER="$ROOT_DIR/scripts/manage-weather-locations.py"
CONFIG="$ROOT_DIR/gnome/weather-locations.local.tsv"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  echo "ERROR: GNOME Weather locations must be restored inside the user's graphical session." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required for GNOME Weather location restore." >&2
  exit 1
fi

if [[ ! -f "$MANAGER" ]]; then
  echo "ERROR: GNOME Weather location manager missing: $MANAGER" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "INFO: private GNOME Weather location config not present; skipping custom locations"
  exit 0
fi

echo "==> Restoring private GNOME Weather custom locations"
python3 "$MANAGER" --config "$CONFIG" --apply
