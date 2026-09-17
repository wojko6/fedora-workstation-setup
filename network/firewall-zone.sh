#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${WIFI_PROFILE:-}"
ZONE="${WIFI_FIREWALL_ZONE:-public}"

iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"

if [[ -z "$iface" ]]; then
  echo "ERROR: default-route interface unavailable; firewall zone not changed." >&2
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  PROFILE="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
fi

if [[ -z "$PROFILE" || "$PROFILE" == "--" ]]; then
  echo "ERROR: NetworkManager profile unavailable for default-route interface: $iface" >&2
  echo "Run with: WIFI_PROFILE='<profile name>' ./network/firewall-zone.sh" >&2
  exit 1
fi

if ! nmcli -t -f NAME connection show | grep -Fxq "$PROFILE"; then
  echo "ERROR: NetworkManager profile not found: $PROFILE" >&2
  exit 1
fi

if ! rpm -q firewalld >/dev/null 2>&1; then
  echo "ERROR: firewalld package is not installed." >&2
  exit 1
fi

if ! systemctl is-active --quiet firewalld; then
  echo "Starting and enabling firewalld"
  sudo systemctl unmask firewalld
  sudo systemctl enable --now firewalld
fi

if ! sudo firewall-cmd --state >/dev/null 2>&1; then
  echo "ERROR: firewalld is not running." >&2
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

echo "Default-route interface: $iface"
echo "Setting NetworkManager firewall zone for profile '$PROFILE': $ZONE"
sudo nmcli connection modify "$PROFILE" connection.zone "$ZONE"

SAVED_ZONE="$(nmcli -g connection.zone connection show "$PROFILE")"
if [[ "$SAVED_ZONE" != "$ZONE" ]]; then
  echo "ERROR: expected saved firewall zone '$ZONE', got '$SAVED_ZONE'" >&2
  exit 1
fi

echo "Saved firewall zone: $SAVED_ZONE"

echo "Allowing KDE Connect / GSConnect in firewalld zone: $ZONE"
sudo firewall-cmd --permanent --zone="$ZONE" --add-service=kdeconnect >/dev/null
sudo firewall-cmd --reload >/dev/null
sudo firewall-cmd --zone="$ZONE" --change-interface="$iface" >/dev/null

ACTIVE_ZONE="$(sudo firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null || true)"
if [[ "$ACTIVE_ZONE" != "$ZONE" ]]; then
  echo "ERROR: expected active firewall zone '$ZONE', got '${ACTIVE_ZONE:-none}'" >&2
  exit 1
fi

if [[ "$(sudo firewall-cmd --zone="$ZONE" --query-service=kdeconnect)" != "yes" ]]; then
  echo "ERROR: kdeconnect service is not enabled in zone '$ZONE'." >&2
  exit 1
fi

echo "Active firewall zone: $ACTIVE_ZONE"
echo "KDE Connect firewalld service: enabled in $ZONE"
