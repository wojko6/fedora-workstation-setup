#!/usr/bin/env bash
set -Eeuo pipefail

ZONE="workstation-tailscale"
IFACE="tailscale0"
COLLECTOR_CONF="${SYSLOG_NG_COLLECTOR_CONF:-/etc/syslog-ng/conf.d/asus-edge-collector.conf}"
COLLECTOR_PORT="${SYSLOG_NG_COLLECTOR_PORT:-6514}"

fail() {
  echo "ERROR: $*" >&2
  return 1
}

for cmd in ip rpm systemctl firewall-cmd sudo sed sort; do
  command -v "$cmd" >/dev/null 2>&1 ||
    fail "required command not found: $cmd"
done

rpm -q firewalld >/dev/null 2>&1 ||
  fail "firewalld package is not installed."
rpm -q tailscale >/dev/null 2>&1 ||
  fail "tailscale package is not installed."


collector_source=""
collector_rich_rule=""

validate_tailscale_ipv4_32() {
  local cidr="$1"
  local ip="${cidr%/32}"
  local a b c d

  [[ "$cidr" == */32 ]] || return 1
  IFS=. read -r a b c d <<<"$ip"
  [[ -n "${a:-}" && -n "${b:-}" && -n "${c:-}" && -n "${d:-}" ]] || return 1

  local octet
  for octet in "$a" "$b" "$c" "$d"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] || return 1
    (( 10#$octet >= 0 && 10#$octet <= 255 )) || return 1
  done

  (( 10#$a == 100 && 10#$b >= 64 && 10#$b <= 127 )) || return 1
}

if [[ -f "$COLLECTOR_CONF" ]]; then
  mapfile -t collector_sources < <(
    sed -nE 's/^[[:space:]]*netmask\("([0-9]{1,3}(\.[0-9]{1,3}){3}\/32)"\);[[:space:]]*$/\1/p' "$COLLECTOR_CONF" |
      sort -u
  )

  (( ${#collector_sources[@]} == 1 )) ||
    fail "expected exactly one IPv4 /32 netmask in $COLLECTOR_CONF for the ASUS Edge collector."

  collector_source="${collector_sources[0]}"
  validate_tailscale_ipv4_32 "$collector_source" ||
    fail "ASUS Edge collector source must be one Tailscale IPv4 /32 in $COLLECTOR_CONF."

  [[ "$COLLECTOR_PORT" =~ ^[0-9]+$ ]] &&
    (( 10#$COLLECTOR_PORT >= 1 && 10#$COLLECTOR_PORT <= 65535 )) ||
    fail "invalid ASUS Edge collector TCP port: $COLLECTOR_PORT"

  collector_rich_rule="rule family=\"ipv4\" source address=\"$collector_source\" port port=\"$COLLECTOR_PORT\" protocol=\"tcp\" accept"
fi

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

if [[ -n "$collector_rich_rule" ]]; then
  sudo firewall-cmd --permanent --zone="$ZONE"     --add-rich-rule="$collector_rich_rule" >/dev/null
fi

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

for option in   --list-services   --list-ports   --list-protocols   --list-source-ports   --list-forward-ports   --list-sources   --list-icmp-blocks; do
  if [[ -n "$(
    sudo firewall-cmd --permanent --zone="$ZONE" "$option" 2>/dev/null |
      xargs
  )" ]]; then
    fail "unexpected permanent state remains in zone '$ZONE': $option"
  fi
done

permanent_rich_rules="$(
  sudo firewall-cmd --permanent --zone="$ZONE" --list-rich-rules 2>/dev/null |
    sed '/^$/d' |
    sort
)"
if [[ -n "$collector_rich_rule" ]]; then
  [[ "$permanent_rich_rules" == "$collector_rich_rule" ]] ||
    fail "permanent collector rich-rule drift in zone '$ZONE'."
else
  [[ -z "$permanent_rich_rules" ]] ||
    fail "unexpected permanent rich rules remain in zone '$ZONE'."
fi

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

runtime_rich_rules="$(
  sudo firewall-cmd --zone="$ZONE" --list-rich-rules 2>/dev/null |
    sed '/^$/d' |
    sort
)"
if [[ -n "$collector_rich_rule" ]]; then
  [[ "$runtime_rich_rules" == "$collector_rich_rule" ]] ||
    fail "runtime collector rich-rule drift in zone '$ZONE'."
else
  [[ -z "$runtime_rich_rules" ]] ||
    fail "unexpected runtime rich rules remain in zone '$ZONE'."
fi

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
echo "PASS: services, explicit ports, protocols, sources, forwarding and masquerade are absent"
if [[ -n "$collector_rich_rule" ]]; then
  echo "PASS: ASUS Edge collector ingress is restricted to one private /32 source on TCP/$COLLECTOR_PORT"
else
  echo "PASS: no inbound rich-rule exception is configured"
fi
