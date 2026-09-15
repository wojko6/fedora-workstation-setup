#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RPM_MANIFEST="$ROOT_DIR/packages/rpm.txt"
EXT_LIST="$ROOT_DIR/gnome/enabled-extensions.txt"

pass=0
warn=0
fail=0

ok()   { printf 'PASS: %s\n' "$*"; pass=$((pass + 1)); }
warn() { printf 'WARN: %s\n' "$*"; warn=$((warn + 1)); }
bad()  { printf 'FAIL: %s\n' "$*"; fail=$((fail + 1)); }

echo "=== SYSTEM ==="
if [[ -r /etc/fedora-release ]]; then
  cat /etc/fedora-release
  ok "Fedora release detected"
else
  bad "/etc/fedora-release missing"
fi

gnome-shell --version 2>/dev/null || warn "GNOME Shell version unavailable"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"

echo
echo "=== RPM MANIFEST ==="
if [[ -f "$RPM_MANIFEST" ]]; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if rpm -q "$pkg" >/dev/null 2>&1; then
      ok "rpm $pkg"
    else
      warn "rpm missing: $pkg"
    fi
  done < "$RPM_MANIFEST"
else
  bad "missing $RPM_MANIFEST"
fi

echo
echo "=== EXTERNAL REPOSITORIES ==="
repo_ids="$(dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}')"
for repo in rpmfusion-free rpmfusion-nonfree brave-browser repo.nordvpn.com_yum_nordvpn_centos_x86_64; do
  if grep -Fxq "$repo" <<<"$repo_ids"; then
    ok "repo $repo"
  else
    warn "repo not enabled: $repo"
  fi
done

echo
echo "=== GNOME EXTENSIONS ==="
if command -v gnome-extensions >/dev/null 2>&1; then
  if [[ -f "$EXT_LIST" ]]; then
    while IFS= read -r uuid; do
      [[ -z "$uuid" || "$uuid" == \#* ]] && continue
      if gnome-extensions info "$uuid" >/dev/null 2>&1; then
        ok "extension installed: $uuid"
      else
        warn "extension missing: $uuid"
      fi
    done < "$EXT_LIST"
  else
    bad "missing $EXT_LIST"
  fi
else
  warn "gnome-extensions command unavailable"
fi

echo
echo "=== WIFI POWER SAVE ==="
iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')"
if [[ -n "$iface" ]]; then
  printf 'Interface: %s\n' "$iface"
  ps="$(iw dev "$iface" get power_save 2>/dev/null || true)"
  printf '%s\n' "$ps"
  if grep -qi 'off' <<<"$ps"; then
    ok "Wi-Fi power save disabled"
  else
    warn "Wi-Fi power save is not confirmed off"
  fi
else
  warn "No Wi-Fi interface detected"
fi

echo
echo "=== FLATPAK APPS ==="
if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application 2>/dev/null || true
else
  warn "flatpak command unavailable"
fi

echo
echo "=== SUMMARY ==="
printf 'PASS=%d WARN=%d FAIL=%d\n' "$pass" "$warn" "$fail"

(( fail == 0 ))
