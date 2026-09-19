#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${WIFI_PROFILE:-}"

command -v nmcli >/dev/null 2>&1 || {
  echo "ERROR: nmcli is required." >&2
  exit 1
}

if [[ -z "$PROFILE" ]]; then
  iface="$(
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
      awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }'
  )"

  if [[ -z "$iface" ]]; then
    if command -v systemd-detect-virt >/dev/null 2>&1 &&
       systemd-detect-virt --quiet; then
      echo "SKIP: no active Wi-Fi interface in virtualized environment."
      exit 0
    fi

    echo "ERROR: no active Wi-Fi interface detected." >&2
    echo "Use WIFI_PROFILE='<profile name>' to select a profile explicitly." >&2
    exit 1
  fi

  PROFILE="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"

  if [[ -z "$PROFILE" || "$PROFILE" == "--" ]]; then
    echo "ERROR: active NetworkManager Wi-Fi profile unavailable for: $iface" >&2
    exit 1
  fi

  printf 'Detected active Wi-Fi profile: %s (%s)\n' "$PROFILE" "$iface"
else
  printf 'Using explicitly supplied Wi-Fi profile: %s\n' "$PROFILE"
fi

if ! nmcli -t -f NAME connection show | grep -Fxq "$PROFILE"; then
  echo "ERROR: NetworkManager profile not found: $PROFILE" >&2
  exit 1
fi

echo "Disabling NetworkManager Wi-Fi power saving for: $PROFILE"
sudo nmcli connection modify "$PROFILE" 802-11-wireless.powersave 2

saved="$(
  LC_ALL=C nmcli -g 802-11-wireless.powersave connection show "$PROFILE" 2>/dev/null ||
    true
)"

if [[ "$saved" != "disable" && "$saved" != "2" ]]; then
  echo "ERROR: expected Wi-Fi power saving to be disabled, got '${saved:-unknown}'." >&2
  exit 1
fi

printf 'PASS: Wi-Fi power saving disabled persistently for: %s\n' "$PROFILE"
printf '%s\n' \
  "Reconnect the profile (or reboot) before verifying runtime power-save state."
