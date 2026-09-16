#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${WIFI_PROFILE:-}"
ZONE="${WIFI_FIREWALL_ZONE:-public}"

if [[ -z "$PROFILE" ]]; then
  echo "Wi-Fi profile not supplied; firewall zone not changed."
  echo "Run with: WIFI_PROFILE='<profile name>' ./network/firewall-zone.sh"
  exit 0
fi

if ! nmcli -t -f NAME connection show | grep -Fxq "$PROFILE"; then
  echo "ERROR: NetworkManager profile not found: $PROFILE" >&2
  exit 1
fi

if ! sudo firewall-cmd --get-zones | tr ' ' '\n' | grep -Fxq "$ZONE"; then
  echo "ERROR: firewalld zone not found: $ZONE" >&2
  exit 1
fi

echo "Setting NetworkManager firewall zone for supplied Wi-Fi profile: $ZONE"
sudo nmcli connection modify "$PROFILE" connection.zone "$ZONE"

SAVED_ZONE="$(nmcli -g connection.zone connection show "$PROFILE")"

if [[ "$SAVED_ZONE" != "$ZONE" ]]; then
  echo "ERROR: expected firewall zone '$ZONE', got '$SAVED_ZONE'" >&2
  exit 1
fi

echo "Saved firewall zone: $SAVED_ZONE"
echo
printf '%s\n' "Reconnect the profile (or reboot) before verifying the active firewalld zone."
