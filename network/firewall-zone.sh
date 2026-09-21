#!/usr/bin/env bash
set -Eeuo pipefail

ZONE="workstation-kdeconnect"
TRUSTED_UUID="${TRUSTED_WIFI_UUID:-}"
EXPECTED_PROFILE="${TRUSTED_WIFI_PROFILE:-}"

fail() {
  echo "ERROR: $*" >&2
  return 1
}

for cmd in ip nmcli rpm systemctl firewall-cmd sudo; do
  command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
done

virt="none"
if command -v systemd-detect-virt >/dev/null 2>&1; then
  virt="$(systemd-detect-virt 2>/dev/null || true)"
  [[ -n "$virt" ]] || virt="none"
fi

if [[ -z "$TRUSTED_UUID" && "$virt" != "none" ]]; then
  echo "SKIP: trusted Wi-Fi firewalld policy is not applied in virtualized environment: $virt"
  exit 0
fi

[[ -n "$TRUSTED_UUID" ]] || fail \
  "TRUSTED_WIFI_UUID is required; refusing to trust the active/default-route network implicitly."

if [[ ! "$TRUSTED_UUID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
  fail "TRUSTED_WIFI_UUID is not a valid NetworkManager UUID: $TRUSTED_UUID"
fi

iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
[[ -n "$iface" ]] || fail "default-route interface unavailable; firewall zone not changed."

active_profile="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
active_uuid="$(nmcli -g GENERAL.CON-UUID device show "$iface" 2>/dev/null || true)"
iface_type="$(
  nmcli -t -f DEVICE,TYPE device status 2>/dev/null |
    awk -F: -v dev="$iface" '$1 == dev { print $2; exit }'
)"

[[ -n "$active_profile" && "$active_profile" != "--" ]] ||
  fail "NetworkManager profile unavailable for default-route interface: $iface"
[[ -n "$active_uuid" && "$active_uuid" != "--" ]] ||
  fail "NetworkManager UUID unavailable for default-route interface: $iface"
[[ "$iface_type" == "wifi" ]] ||
  fail "default-route interface is not Wi-Fi: $iface (type: ${iface_type:-unknown})"

if [[ "$active_uuid" != "$TRUSTED_UUID" ]]; then
  fail "active Wi-Fi profile is not trusted: $active_profile ($active_uuid)"
fi

if [[ -n "$EXPECTED_PROFILE" && "$active_profile" != "$EXPECTED_PROFILE" ]]; then
  fail "trusted Wi-Fi profile name mismatch: expected '$EXPECTED_PROFILE', active '$active_profile'"
fi

PROFILE="$active_profile"
profile_uuid="$(nmcli -g connection.uuid connection show "$PROFILE" 2>/dev/null || true)"
profile_type="$(nmcli -g connection.type connection show "$PROFILE" 2>/dev/null || true)"

[[ "$profile_uuid" == "$TRUSTED_UUID" ]] ||
  fail "profile UUID changed during preflight: expected $TRUSTED_UUID, found ${profile_uuid:-none}"
[[ "$profile_type" == "802-11-wireless" ]] ||
  fail "trusted NetworkManager profile is not Wi-Fi: $PROFILE (type: ${profile_type:-unknown})"

rpm -q firewalld >/dev/null 2>&1 ||
  fail "firewalld package is not installed."

# Trust validation above must complete before any system/firewall mutation.
if ! systemctl is-active --quiet firewalld; then
  echo "Starting and enabling firewalld"
  sudo systemctl unmask firewalld
  sudo systemctl enable --now firewalld
fi

sudo firewall-cmd --state >/dev/null 2>&1 ||
  fail "firewalld is not running."

desired_services=(dhcpv6-client mdns kdeconnect)

for service in "${desired_services[@]}"; do
  if ! sudo firewall-cmd --get-services |
       tr ' ' '\n' |
       grep -Fxq "$service"; then
    fail "firewalld service definition unavailable: $service"
  fi
done

# Reject KDE Connect exposure in any other currently active zone.
while IFS= read -r active_other_zone; do
  [[ -z "$active_other_zone" || "$active_other_zone" == "$ZONE" ]] && continue
  if sudo firewall-cmd --zone="$active_other_zone"       --query-service=kdeconnect >/dev/null 2>&1; then
    fail "kdeconnect is enabled in another active zone: $active_other_zone"
  fi
done < <(
  sudo firewall-cmd --get-active-zones |
    awk '/^[^[:space:]]/ { print $1 }'
)

zone_existed=0
if sudo firewall-cmd --permanent --get-zones |
   tr ' ' '\n' |
   grep -Fxq "$ZONE"; then
  zone_existed=1
fi

old_profile_zone="$(nmcli -g connection.zone connection show "$PROFILE" 2>/dev/null || true)"

snapshot_words() {
  local option="$1"
  sudo firewall-cmd --permanent --zone="$ZONE" "$option" 2>/dev/null |
    tr ' ' '\n' |
    sed '/^$/d'
}

snapshot_lines() {
  local option="$1"
  sudo firewall-cmd --permanent --zone="$ZONE" "$option" 2>/dev/null |
    sed '/^$/d'
}

old_target="default"
old_forward=0
old_masquerade=0
old_icmp_inversion=0
old_services=()
old_ports=()
old_protocols=()
old_source_ports=()
old_forward_ports=()
old_sources=()
old_icmp_blocks=()
old_rich_rules=()

if (( zone_existed )); then
  old_target="$(sudo firewall-cmd --permanent --zone="$ZONE" --get-target 2>/dev/null || echo default)"
  sudo firewall-cmd --permanent --zone="$ZONE" --query-forward >/dev/null 2>&1 &&
    old_forward=1
  sudo firewall-cmd --permanent --zone="$ZONE" --query-masquerade >/dev/null 2>&1 &&
    old_masquerade=1
  sudo firewall-cmd --permanent --zone="$ZONE" --query-icmp-block-inversion >/dev/null 2>&1 &&
    old_icmp_inversion=1
  mapfile -t old_services < <(snapshot_words --list-services)
  mapfile -t old_ports < <(snapshot_words --list-ports)
  mapfile -t old_protocols < <(snapshot_words --list-protocols)
  mapfile -t old_source_ports < <(snapshot_words --list-source-ports)
  mapfile -t old_forward_ports < <(snapshot_words --list-forward-ports)
  mapfile -t old_sources < <(snapshot_words --list-sources)
  mapfile -t old_icmp_blocks < <(snapshot_words --list-icmp-blocks)
  mapfile -t old_rich_rules < <(snapshot_lines --list-rich-rules)
fi

remove_all_words() {
  local list_option="$1"
  local remove_option="$2"
  local item
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    sudo firewall-cmd --permanent --zone="$ZONE" "$remove_option=$item" >/dev/null
  done < <(snapshot_words "$list_option")
}

remove_all_rich_rules() {
  local rule
  while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    sudo firewall-cmd --permanent --zone="$ZONE"       --remove-rich-rule="$rule" >/dev/null
  done < <(snapshot_lines --list-rich-rules)
}

clear_zone_state() {
  remove_all_words --list-services --remove-service
  remove_all_words --list-ports --remove-port
  remove_all_words --list-protocols --remove-protocol
  remove_all_words --list-source-ports --remove-source-port
  remove_all_words --list-forward-ports --remove-forward-port
  remove_all_words --list-sources --remove-source
  remove_all_words --list-icmp-blocks --remove-icmp-block
  remove_all_rich_rules

  sudo firewall-cmd --permanent --zone="$ZONE" --remove-forward >/dev/null 2>&1 || true
  sudo firewall-cmd --permanent --zone="$ZONE" --remove-masquerade >/dev/null 2>&1 || true
  sudo firewall-cmd --permanent --zone="$ZONE" --remove-icmp-block-inversion >/dev/null 2>&1 || true
}

restore_array() {
  local add_option="$1"
  shift
  local item
  for item in "$@"; do
    [[ -z "$item" ]] && continue
    sudo firewall-cmd --permanent --zone="$ZONE" "$add_option=$item" >/dev/null
  done
}

rollback() {
  local rc=$?
  trap - ERR
  set +e
  echo "ERROR: firewall configuration failed; restoring previous state." >&2

  sudo nmcli connection modify "$PROFILE" connection.zone "$old_profile_zone" >/dev/null 2>&1

  if (( zone_existed )); then
    clear_zone_state
    sudo firewall-cmd --permanent --zone="$ZONE" --set-target="$old_target" >/dev/null 2>&1
    restore_array --add-service "${old_services[@]}"
    restore_array --add-port "${old_ports[@]}"
    restore_array --add-protocol "${old_protocols[@]}"
    restore_array --add-source-port "${old_source_ports[@]}"
    restore_array --add-forward-port "${old_forward_ports[@]}"
    restore_array --add-source "${old_sources[@]}"
    restore_array --add-icmp-block "${old_icmp_blocks[@]}"
    restore_array --add-rich-rule "${old_rich_rules[@]}"
    (( old_forward )) && sudo firewall-cmd --permanent --zone="$ZONE" --add-forward >/dev/null 2>&1
    (( old_masquerade )) && sudo firewall-cmd --permanent --zone="$ZONE" --add-masquerade >/dev/null 2>&1
    (( old_icmp_inversion )) && sudo firewall-cmd --permanent --zone="$ZONE" --add-icmp-block-inversion >/dev/null 2>&1
  else
    sudo firewall-cmd --permanent --delete-zone="$ZONE" >/dev/null 2>&1
  fi

  sudo firewall-cmd --reload >/dev/null 2>&1
  exit "$rc"
}
trap rollback ERR

if (( ! zone_existed )); then
  echo "Creating dedicated firewalld zone: $ZONE"
  sudo firewall-cmd --permanent --new-zone="$ZONE" >/dev/null
fi

echo "Applying exact-state policy to trusted Wi-Fi profile: $PROFILE ($TRUSTED_UUID)"

clear_zone_state
sudo firewall-cmd --permanent --zone="$ZONE" --set-target=default >/dev/null

for service in "${desired_services[@]}"; do
  sudo firewall-cmd --permanent --zone="$ZONE" --add-service="$service" >/dev/null
done

sudo nmcli connection modify "$PROFILE" connection.zone "$ZONE"
sudo firewall-cmd --reload >/dev/null
sudo firewall-cmd --zone="$ZONE" --change-interface="$iface" >/dev/null

saved_zone="$(nmcli -g connection.zone connection show "$PROFILE" 2>/dev/null || true)"
[[ "$saved_zone" == "$ZONE" ]] ||
  fail "expected saved firewall zone '$ZONE', got '${saved_zone:-none}'."

active_zone="$(sudo firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null || true)"
[[ "$active_zone" == "$ZONE" ]] ||
  fail "expected active firewall zone '$ZONE', got '${active_zone:-none}'."

actual_services="$(
  sudo firewall-cmd --permanent --zone="$ZONE" --list-services |
    tr ' ' '\n' |
    sed '/^$/d' |
    sort
)"
expected_services="$(printf '%s\n' "${desired_services[@]}" | sort)"

[[ "$actual_services" == "$expected_services" ]] ||
  fail "firewalld service drift remains in zone '$ZONE'."

for option in   --list-ports   --list-protocols   --list-source-ports   --list-forward-ports   --list-sources   --list-icmp-blocks   --list-rich-rules; do
  if [[ -n "$(sudo firewall-cmd --permanent --zone="$ZONE" "$option" 2>/dev/null | xargs)" ]]; then
    fail "unexpected firewalld state remains in zone '$ZONE': $option"
  fi
done

if sudo firewall-cmd --permanent --zone="$ZONE" --query-forward >/dev/null 2>&1; then
  fail "forwarding must be disabled in zone '$ZONE'."
fi
if sudo firewall-cmd --permanent --zone="$ZONE" --query-masquerade >/dev/null 2>&1; then
  fail "masquerade must be disabled in zone '$ZONE'."
fi
if sudo firewall-cmd --permanent --zone="$ZONE" --query-icmp-block-inversion >/dev/null 2>&1; then
  fail "ICMP block inversion must be disabled in zone '$ZONE'."
fi

trap - ERR

echo "PASS: trusted Wi-Fi profile uses exact-state firewalld zone: $ZONE"
echo "PASS: services = dhcpv6-client mdns kdeconnect"
echo "PASS: ssh, forwarding, masquerade, ports, protocols, sources, forward-ports, source-ports, ICMP blocks, and rich rules are absent"
