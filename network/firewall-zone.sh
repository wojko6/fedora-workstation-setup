#!/usr/bin/env bash
set -Eeuo pipefail

ZONE="workstation-kdeconnect"
fail() {
  echo "ERROR: $*" >&2
  return 1
}

for cmd in ip nmcli rpm systemctl firewall-cmd sudo; do
  command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
done

# Repeat the identity check immediately before using the interface and profile.
source "$(dirname -- "${BASH_SOURCE[0]}")/check-trusted-wifi.sh"

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

zone_existed=0
if sudo firewall-cmd --permanent --get-zones |
   tr ' ' '\n' |
   grep -Fxq "$ZONE"; then
  zone_existed=1
fi

old_profile_zone="$(nmcli -g connection.zone connection show "$PROFILE" 2>/dev/null || true)"

other_kdeconnect_zones=()
while IFS= read -r other_zone; do
  [[ -z "$other_zone" || "$other_zone" == "$ZONE" ]] && continue
  if sudo firewall-cmd --permanent --zone="$other_zone" \
      --query-service=kdeconnect >/dev/null 2>&1; then
    other_kdeconnect_zones+=("$other_zone")
  fi
done < <(
  sudo firewall-cmd --permanent --get-zones |
    tr ' ' '\n' |
    sed '/^$/d'
)

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

  for other_zone in "${other_kdeconnect_zones[@]}"; do
    sudo firewall-cmd --permanent --zone="$other_zone" \
      --add-service=kdeconnect >/dev/null 2>&1
  done

  sudo firewall-cmd --reload >/dev/null 2>&1
  exit "$rc"
}
trap rollback ERR

if (( ! zone_existed )); then
  echo "Creating dedicated firewalld zone: $ZONE"
  sudo firewall-cmd --permanent --new-zone="$ZONE" >/dev/null
fi

echo "Applying exact-state policy to trusted Wi-Fi profile: $PROFILE ($TRUSTED_UUID)"

for other_zone in "${other_kdeconnect_zones[@]}"; do
  echo "Removing KDE Connect from non-trusted firewalld zone: $other_zone"
  sudo firewall-cmd --permanent --zone="$other_zone" \
    --remove-service=kdeconnect >/dev/null
done

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

while IFS= read -r other_zone; do
  [[ -z "$other_zone" || "$other_zone" == "$ZONE" ]] && continue
  if sudo firewall-cmd --permanent --zone="$other_zone" \
      --query-service=kdeconnect >/dev/null 2>&1; then
    fail "kdeconnect remains enabled in non-trusted zone: $other_zone"
  fi
done < <(
  sudo firewall-cmd --permanent --get-zones |
    tr ' ' '\n' |
    sed '/^$/d'
)

trap - ERR

echo "PASS: trusted Wi-Fi profile uses exact-state firewalld zone: $ZONE"
echo "PASS: services = dhcpv6-client mdns kdeconnect"
echo "PASS: kdeconnect is absent from all other permanent firewalld zones"
echo "PASS: ssh, forwarding, masquerade, ports, protocols, sources, forward-ports, source-ports, ICMP blocks, and rich rules are absent"
