#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${WIFI_PROFILE:-}"
ZONE="${WIFI_FIREWALL_ZONE:-public}"

if [[ -z "$PROFILE" ]]; then
  iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')"
  if [[ -n "$iface" ]]; then
    PROFILE="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
  fi
fi

if [[ -z "$PROFILE" || "$PROFILE" == "--" ]]; then
  echo "Wi-Fi profile unavailable; firewall zone not changed."
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

if ! sudo firewall-cmd --get-services | tr ' ' '\n' | grep -Fxq kdeconnect; then
  echo "ERROR: firewalld service definition 'kdeconnect' is unavailable." >&2
  exit 1
fi

echo "Setting NetworkManager firewall zone for Wi-Fi profile '$PROFILE': $ZONE"
sudo nmcli connection modify "$PROFILE" connection.zone "$ZONE"

SAVED_ZONE="$(nmcli -g connection.zone connection show "$PROFILE")"
if [[ "$SAVED_ZONE" != "$ZONE" ]]; then
  echo "ERROR: expected firewall zone '$ZONE', got '$SAVED_ZONE'" >&2
  exit 1
fi

echo "Saved firewall zone: $SAVED_ZONE"

echo "Allowing KDE Connect / GSConnect in firewalld zone: $ZONE"
sudo firewall-cmd --permanent --zone="$ZONE" --add-service=kdeconnect >/dev/null
sudo firewall-cmd --reload >/dev/null

if [[ "$(sudo firewall-cmd --zone="$ZONE" --query-service=kdeconnect)" != "yes" ]]; then
  echo "ERROR: kdeconnect service is not enabled in zone '$ZONE'." >&2
  exit 1
fi

echo "KDE Connect firewalld service: enabled in $ZONE"
echo
printf '%s\n' "Reconnect the profile (or reboot) before verifying the active firewalld zone if the profile was previously using a different zone."
