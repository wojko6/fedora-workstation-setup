#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$ROOT_DIR/gnome/settings.dconf"

if [[ ! -f "$SETTINGS" ]]; then
  echo "ERROR: missing $SETTINGS" >&2
  exit 1
fi
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  echo "ERROR: run this inside the user's graphical session." >&2
  exit 1
fi

pass=0
warn=0

ok() { printf 'PASS: %s\n' "$*"; ((pass+=1)); }
no() { printf 'WARN: %s\n' "$*"; ((warn+=1)); }

section=""
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ "$line" =~ ^\[(.+)\]$ ]]; then
    section="/${BASH_REMATCH[1]}/"
    continue
  fi
  [[ -z "$section" || "$line" != *=* ]] && continue

  key="${line%%=*}"
  expected="${line#*=}"
  current="$(dconf read "${section}${key}" 2>/dev/null || true)"

  path="${section}${key}"

  # The order of GNOME favorite applications is intentionally not part of
  # desired state. Require the same applications, but allow the user to
  # rearrange their icons freely.
  if [[ "$path" == "/org/gnome/shell/favorite-apps" ]]; then
    expected_sorted="$(printf '%s\n' "$expected" | tr -d "[]' " | tr ',' '\n' | sort)"
    current_sorted="$(printf '%s\n' "$current" | tr -d "[]' " | tr ',' '\n' | sort)"

    if [[ "$current_sorted" == "$expected_sorted" ]]; then
      ok "$path"
    else
      no "$path expected=${expected} current=${current:-<unset>}"
    fi
  elif [[ "$current" == "$expected" ]]; then
    ok "$path"
  else
    no "$path expected=${expected} current=${current:-<unset>}"
  fi
done < "$SETTINGS"

printf '\n=== GNOME AUDIT SUMMARY ===\nPASS=%d WARN=%d\n' "$pass" "$warn"

# Audit only: differences are reported as WARN so this command remains safe to
# use on a working workstation and never modifies dconf.
exit 0
