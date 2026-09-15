#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${WIFI_PROFILE:-}"

if [[ -z "$PROFILE" ]]; then
  echo "Wi-Fi profile not supplied; no network setting changed."
  echo "Run with: WIFI_PROFILE='<profile name>' ./network/wifi-power-save.sh"
  exit 0
fi

if ! nmcli -t -f NAME connection show | grep -Fxq "$PROFILE"; then
  echo "ERROR: NetworkManager profile not found: $PROFILE" >&2
  exit 1
fi

echo "Disabling NetworkManager Wi-Fi power saving for: $PROFILE"
sudo nmcli connection modify "$PROFILE" 802-11-wireless.powersave 2

echo "Saved setting:"
nmcli -f 802-11-wireless.powersave connection show "$PROFILE"

echo
printf '%s\n' "Reconnect the profile (or reboot) before verifying runtime power-save state."
