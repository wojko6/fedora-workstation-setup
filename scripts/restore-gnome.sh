#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$ROOT_DIR/gnome/settings.dconf"
EXTENSIONS="$ROOT_DIR/gnome/enabled-extensions.txt"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  echo "ERROR: restore-gnome.sh must run inside the user's graphical session." >&2
  exit 1
fi

if [[ ! -f "$SETTINGS" ]]; then
  echo "ERROR: missing $SETTINGS" >&2
  exit 1
fi

echo "==> Restoring curated GNOME settings"

# GNOME favorite applications are audit-only. Dhruva is the canonical dock,
# and its order/folder state is restored separately by install-dhruva-config.sh.
# Keep favorite-apps in settings.dconf as the expected membership set for the
# audit, but never write that key during GNOME restore so user icon ordering is
# not changed as a side effect of a rebuild.
tmp_settings="$(mktemp)"
trap 'rm -f "$tmp_settings"' EXIT

awk '
  /^\[org\/gnome\/shell\]$/ { in_shell = 1; print; next }
  /^\[/ { in_shell = 0 }
  in_shell && /^favorite-apps=/ { next }
  { print }
' "$SETTINGS" > "$tmp_settings"

dconf load / < "$tmp_settings"

if command -v gnome-extensions >/dev/null 2>&1 && [[ -f "$EXTENSIONS" ]]; then
  echo "==> Enabling installed GNOME extensions"
  while IFS= read -r uuid; do
    [[ -z "$uuid" || "$uuid" == \#* ]] && continue
    if gnome-extensions info "$uuid" >/dev/null 2>&1; then
      gnome-extensions enable "$uuid" || printf 'WARN: could not enable %s\n' "$uuid" >&2
    else
      printf 'SKIP: extension not installed: %s\n' "$uuid"
    fi
  done < "$EXTENSIONS"
fi

echo "GNOME restore completed. Log out and back in if Shell changes are not immediately visible."
