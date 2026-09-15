#!/usr/bin/env bash
set -u

echo "=== SYSTEM ==="
cat /etc/fedora-release 2>/dev/null || true
gnome-shell --version 2>/dev/null || true
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"

echo
echo "=== GNOME EXTENSIONS ==="
gnome-extensions list --enabled 2>/dev/null || true

echo
echo "=== WIFI POWER SAVE ==="
iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')"
if [[ -n "$iface" ]]; then
  printf 'Interface: %s\n' "$iface"
  iw dev "$iface" get power_save 2>/dev/null || true
else
  echo "No Wi-Fi interface detected."
fi

echo
echo "=== FLATPAK APPS ==="
flatpak list --app --columns=application 2>/dev/null || true
