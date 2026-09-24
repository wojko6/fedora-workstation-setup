#!/usr/bin/env bash
set -Eeuo pipefail

ZONE="workstation-tailscale"
IFACE="tailscale0"

fail() {
  echo "ERROR: $*" >&2
  return 1
}

for cmd in ip rpm systemctl firewall-cmd sudo; do
  command -v "$cmd" >/dev/null 2>&1 ||
    fail "required command not found: $cmd"
done

rpm -q firewalld >/dev/null 2>&1 ||
  fail "firewalld package is not installed."
rpm -q tailscale >/dev/null 2>&1 ||
  fail "tailscale package is not installed."

if ! systemctl is-active --quiet firewalld; then
  echo "Starting and enabling firewalld"
  sudo systemctl unmask firewalld
  sudo systemctl enable --now firewalld
fi

sudo firewall-cmd --state >/dev/null 2>&1 ||
  fail "firewalld is not running."

zone_existed=0
if sudo firewall-cmd --permanent --get-zones |
   tr ' ' '\n' |
   grep -Fxq "$ZONE"; then
  zone_existed=1
fi

old_iface_zone="$(
  sudo firewall-cmd --permanent --get-zone-of-interface="$IFACE" 2>/dev/null || true
)"
[[ "$old_iface_zone" == "no zone" ]] && old_iface_zone=""

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
old_interfaces=()
old_services=()
old_ports=()
old_protocols=()
old_source_ports=()
old_forward_ports=()
old_sources=()
old_icmp_blocks=()
old_rich_rules=()

if (( zone_existed )); then
  old_target="$(
    sudo firewall-cmd --permanent --zone="$ZONE" --get-target 2>/dev/null ||
      echo default
  )"
  sudo firewall-cmd --permanent --zone="$ZONE" --query-forward >/dev/null 2>&1 &&
    old_forward=1
  sudo firewall-cmd --permanent --zone="$ZONE" --query-masquerade >/dev/null 2>&1 &&
    old_masquerade=1
  sudo firewall-cmd --permanent --zone="$ZONE" --query-icmp-block-inversion >/dev/null 2>&1 &&
    old_icmp_inversion=1
  mapfile -t old_interfaces < <(snapshot_words --list-interfaces)
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
  remove_all_words --list-interfaces --remove-interface
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
  echo "ERROR: Tailscale firewalld configuration failed; restoring previous state." >&2

  if (( zone_existed )); then
    clear_zone_state
    sudo firewall-cmd --permanent --zone="$ZONE"       --set-target="$old_target" >/dev/null 2>&1
    restore_array --add-interface "${old_interfaces[@]}"
    restore_array --add-service "${old_services[@]}"
    restore_array --add-port "${old_ports[@]}"
    restore_array --add-protocol "${old_protocols[@]}"
    restore_array --add-source-port "${old_source_ports[@]}"
    restore_array --add-forward-port "${old_forward_ports[@]}"
    restore_array --add-source "${old_sources[@]}"
    restore_array --add-icmp-block "${old_icmp_blocks[@]}"
    restore_array --add-rich-rule "${old_rich_rules[@]}"
    (( old_forward )) &&
      sudo firewall-cmd --permanent --zone="$ZONE" --add-forward >/dev/null 2>&1
    (( old_masquerade )) &&
      sudo firewall-cmd --permanent --zone="$ZONE" --add-masquerade >/dev/null 2>&1
    (( old_icmp_inversion )) &&
      sudo firewall-cmd --permanent --zone="$ZONE"         --add-icmp-block-inversion >/dev/null 2>&1
  else
    sudo firewall-cmd --permanent --delete-zone="$ZONE" >/dev/null 2>&1
  fi

  if [[ -n "$old_iface_zone" && "$old_iface_zone" != "$ZONE" ]]; then
    sudo firewall-cmd --permanent --zone="$old_iface_zone"       --add-interface="$IFACE" >/dev/null 2>&1
  fi

  sudo firewall-cmd --reload >/dev/null 2>&1
  exit "$rc"
}
trap rollback ERR

if (( ! zone_existed )); then
  echo "Creating dedicated firewalld zone: $ZONE"
  sudo firewall-cmd --permanent --new-zone="$ZONE" >/dev/null
fi

echo "Applying exact-state Tailscale firewalld policy: $ZONE"

if [[ -n "$old_iface_zone" && "$old_iface_zone" != "$ZONE" ]]; then
  sudo firewall-cmd --permanent --zone="$old_iface_zone"     --remove-interface="$IFACE" >/dev/null
fi

clear_zone_state
sudo firewall-cmd --permanent --zone="$ZONE" --set-target=DROP >/dev/null
sudo firewall-cmd --permanent --zone="$ZONE" --add-interface="$IFACE" >/dev/null

permanent_interfaces="$(
  sudo firewall-cmd --permanent --zone="$ZONE" --list-interfaces |
    tr ' ' '\n' |
    sed '/^$/d' |
    sort
)"
[[ "$permanent_interfaces" == "$IFACE" ]] ||
  fail "permanent zone interface drift: expected $IFACE, found '${permanent_interfaces:-none}'."

permanent_target="$(
  sudo firewall-cmd --permanent --zone="$ZONE" --get-target 2>/dev/null || true
)"
[[ "$permanent_target" == "DROP" ]] ||
  fail "permanent zone target drift: expected DROP, found '${permanent_target:-unknown}'."

for option in   --list-services   --list-ports   --list-protocols   --list-source-ports   --list-forward-ports   --list-sources   --list-icmp-blocks   --list-rich-rules; do
  if [[ -n "$(
    sudo firewall-cmd --permanent --zone="$ZONE" "$option" 2>/dev/null |
      xargs
  )" ]]; then
    fail "unexpected permanent state remains in zone '$ZONE': $option"
  fi
done

if sudo firewall-cmd --permanent --zone="$ZONE" --query-forward >/dev/null 2>&1; then
  fail "forwarding must be disabled in zone '$ZONE'."
fi
if sudo firewall-cmd --permanent --zone="$ZONE" --query-masquerade >/dev/null 2>&1; then
  fail "masquerade must be disabled in zone '$ZONE'."
fi
if sudo firewall-cmd --permanent --zone="$ZONE"     --query-icmp-block-inversion >/dev/null 2>&1; then
  fail "ICMP block inversion must be disabled in zone '$ZONE'."
fi

sudo firewall-cmd --reload >/dev/null

runtime_target="$(
  sudo firewall-cmd --zone="$ZONE" --get-target 2>/dev/null || true
)"
[[ "$runtime_target" == "DROP" ]] ||
  fail "runtime zone target drift: expected DROP, found '${runtime_target:-unknown}'."

if ip link show "$IFACE" >/dev/null 2>&1; then
  active_zone="$(
    sudo firewall-cmd --get-zone-of-interface="$IFACE" 2>/dev/null || true
  )"
  [[ "$active_zone" == "$ZONE" ]] ||
    fail "active Tailscale zone drift: expected $ZONE, found '${active_zone:-none}'."
else
  echo "INFO: $IFACE is not present yet; permanent interface binding is prepared."
fi

trap - ERR

echo "PASS: Tailscale interface is bound to dedicated firewalld zone: $ZONE"
echo "PASS: target = DROP"
echo "PASS: services, ports, protocols, sources, forwarding and masquerade are absent"
