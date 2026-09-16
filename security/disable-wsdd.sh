#!/usr/bin/env bash
set -Eeuo pipefail

SCHEMA="org.gnome.system.wsdd"
KEY="display-mode"
DESIRED="disabled"

if ! command -v gsettings >/dev/null 2>&1; then
  echo "ERROR: gsettings is unavailable; cannot configure GNOME WSDD discovery." >&2
  exit 1
fi

if ! gsettings list-schemas | grep -Fxq "$SCHEMA"; then
  echo "ERROR: GNOME WSDD schema is unavailable: $SCHEMA" >&2
  exit 1
fi

echo "Disabling GNOME/GVfs WSDD network discovery..."
gsettings set "$SCHEMA" "$KEY" "$DESIRED"

current="$(gsettings get "$SCHEMA" "$KEY")"
if [[ "$current" != "'$DESIRED'" ]]; then
  echo "ERROR: failed to set $SCHEMA $KEY to '$DESIRED' (current: $current)." >&2
  exit 1
fi

echo "GNOME/GVfs WSDD discovery disabled."
