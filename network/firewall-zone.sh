#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${WIFI_PROFILE:-}"
ZONE="workstation-kdeconnect"
PUBLIC_ZONE="public"

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

required_services=(
  dhcpv6-client
  mdns
  ssh
  kdeconnect
)

for service in "${required_services[@]}"; do
  if ! sudo firewall-cmd --get-services | tr ' ' '\n' | grep -Fxq "$service"; then
    echo "ERROR: firewalld service definition unavailable: $service" >&2
    exit 1
  fi
done

if ! sudo firewall-cmd --permanent --get-zones |
     tr ' ' '\n' |
     grep -Fxq "$ZONE"; then
  echo "Creating dedicated firewalld zone: $ZONE"
  sudo firewall-cmd --permanent --new-zone="$ZONE" >/dev/null
fi

echo "Configuring dedicated Wi-Fi/KDE Connect zone: $ZONE"

if ! sudo firewall-cmd --permanent --zone="$ZONE" \
     --query-forward >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --zone="$ZONE" --add-forward >/dev/null
fi

for service in "${required_services[@]}"; do
  if ! sudo firewall-cmd --permanent --zone="$ZONE" \
       --query-service="$service" >/dev/null 2>&1; then
    sudo firewall-cmd --permanent --zone="$ZONE" \
      --add-service="$service" >/dev/null
  fi
done

if sudo firewall-cmd --permanent --zone="$PUBLIC_ZONE" \
     --query-service=kdeconnect >/dev/null 2>&1; then
  echo "Removing KDE Connect from shared firewalld zone: $PUBLIC_ZONE"
  sudo firewall-cmd --permanent --zone="$PUBLIC_ZONE" \
    --remove-service=kdeconnect >/dev/null
fi

echo "Assigning NetworkManager profile '$PROFILE' to zone: $ZONE"
sudo nmcli connection modify "$PROFILE" connection.zone "$ZONE"

sudo firewall-cmd --reload >/dev/null

# NetworkManager normally applies the zone change immediately. Enforce the
# expected runtime association as well without creating a permanent
# interface-to-zone binding outside NetworkManager.
sudo firewall-cmd --zone="$ZONE" --change-interface="$iface" >/dev/null

saved_zone="$(nmcli -g connection.zone connection show "$PROFILE" 2>/dev/null || true)"
if [[ "$saved_zone" != "$ZONE" ]]; then
  echo "ERROR: expected saved firewall zone '$ZONE', got '${saved_zone:-none}'." >&2
  exit 1
fi

active_zone="$(sudo firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null || true)"
if [[ "$active_zone" != "$ZONE" ]]; then
  echo "ERROR: expected active firewall zone '$ZONE', got '${active_zone:-none}'." >&2
  exit 1
fi

if ! sudo firewall-cmd --zone="$ZONE" --query-service=kdeconnect >/dev/null; then
  echo "ERROR: kdeconnect service is not enabled in zone '$ZONE'." >&2
  exit 1
fi

if sudo firewall-cmd --zone="$PUBLIC_ZONE" \
     --query-service=kdeconnect >/dev/null 2>&1; then
  echo "ERROR: kdeconnect remains enabled in shared zone '$PUBLIC_ZONE'." >&2
  exit 1
fi

echo "Active firewall zone: $active_zone"
echo "KDE Connect firewalld service: isolated to $ZONE"
