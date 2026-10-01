#!/usr/bin/env bash
set -u
set -o pipefail

pass=0
warn=0
fail=0
skip=0

ok()   { printf 'PASS: %s\n' "$*"; pass=$((pass + 1)); }
warn() { printf 'WARN: %s\n' "$*"; warn=$((warn + 1)); }
bad()  { printf 'FAIL: %s\n' "$*"; fail=$((fail + 1)); }
skip() { printf 'SKIP: %s\n' "$*"; skip=$((skip + 1)); }

virt="none"
if command -v systemd-detect-virt >/dev/null 2>&1; then
  virt="$(systemd-detect-virt 2>/dev/null || true)"
  [[ -n "$virt" ]] || virt="none"
fi
is_vm=0
[[ "$virt" != "none" ]] && is_vm=1

LOCKDOWN_FILE="${VERIFY_LOCKDOWN_FILE:-/sys/kernel/security/lockdown}"
AKMOD_CERT="${VERIFY_AKMOD_CERT:-/etc/pki/akmods/certs/public_key.der}"
ZONE="workstation-kdeconnect"
TAILSCALE_ZONE="workstation-tailscale"
TAILSCALE_IFACE="tailscale0"
SYSLOG_NG_COLLECTOR_CONF="${SYSLOG_NG_COLLECTOR_CONF:-/etc/syslog-ng/conf.d/asus-edge-collector.conf}"
SYSLOG_NG_COLLECTOR_PORT="${SYSLOG_NG_COLLECTOR_PORT:-6514}"

echo "=== EXPLICIT SECURITY POSTURE ==="
printf 'Virtualization: %s\n' "$virt"

echo
echo "--- SELINUX / AVC ---"
if command -v getenforce >/dev/null 2>&1; then
  selinux_state="$(getenforce 2>/dev/null || true)"
  if [[ "$selinux_state" == "Enforcing" ]]; then
    ok "SELinux enforcing"
  else
    bad "SELinux state is not Enforcing: ${selinux_state:-unknown}"
  fi
else
  bad "getenforce unavailable"
fi

is_known_syslog_ng_execmem() {
  local record="$1"

  [[ "$record" == type=AVC* ]] || return 1
  grep -Eq 'avc:[[:space:]]+denied[[:space:]]+\{[[:space:]]*execmem[[:space:]]*\}' <<<"$record" || return 1
  grep -Eq 'comm="?syslog-ng-main"?' <<<"$record" || return 1
  grep -Fq 'scontext=system_u:system_r:syslogd_t:s0' <<<"$record" || return 1
  grep -Fq 'tcontext=system_u:system_r:syslogd_t:s0' <<<"$record" || return 1
  grep -Fq 'tclass=process' <<<"$record" || return 1
  grep -Fq 'permissive=0' <<<"$record" || return 1

  command -v rpm >/dev/null 2>&1 || return 1
  rpm -q syslog-ng >/dev/null 2>&1 || return 1
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl is-active --quiet syslog-ng.service >/dev/null 2>&1 || return 1
}

is_systemd_rfkill_capability_candidate() {
  local record="$1"

  [[ "$record" == type=AVC* ]] || return 1
  grep -Eq 'avc:[[:space:]]+denied[[:space:]]+\{[[:space:]]*(dac_override|dac_read_search)[[:space:]]*\}' <<<"$record" || return 1
  grep -Eq 'comm="?systemd-rfkill"?' <<<"$record" || return 1
  grep -Fq 'scontext=system_u:system_r:systemd_rfkill_t:s0' <<<"$record" || return 1
  grep -Fq 'tcontext=system_u:system_r:systemd_rfkill_t:s0' <<<"$record" || return 1
  grep -Fq 'tclass=capability' <<<"$record" || return 1
  grep -Fq 'permissive=0' <<<"$record" || return 1
}

audit_serial_from_record() {
  local record="$1"
  sed -nE 's/.*msg=audit\([^:]+:([0-9]+)\):.*/\1/p' <<<"$record"
}

audit_event_by_serial() {
  local serial="$1"

  if [[ "$audit_method" == "ausearch" ]]; then
    env LC_ALL=C LANG=C ausearch -a "$serial" -ts boot -i 2>/dev/null
  elif [[ "$audit_method" == "sudo ausearch" ]]; then
    sudo env LC_ALL=C LANG=C ausearch -a "$serial" -ts boot -i 2>/dev/null
  else
    return 1
  fi
}

is_current_write_only_sysfs_uevent_inode() {
  local inode="$1"
  local match=""

  [[ "$inode" =~ ^[0-9]+$ ]] || return 1
  command -v find >/dev/null 2>&1 || return 1

  match="$(
    find /sys/module /sys/bus -xdev       -type f       -name uevent       -inum "$inode"       -perm /200       ! -perm /400       -print -quit 2>/dev/null ||
      true
  )"

  [[ -n "$match" ]]
}

is_known_systemd_rfkill_write_only_uevent_event() {
  local event="$1"
  local path_line inode avc_count

  grep -Eq '^type=PROCTITLE .*proctitle=.*/usr/lib/systemd/systemd-rfkill([[:space:]]|$)' <<<"$event" || return 1
  grep -Eq '^type=SYSCALL .*syscall=(openat|openat2) .*success=no .*exit=EACCES.*comm=systemd-rfkill .*subj=system_u:system_r:systemd_rfkill_t:s0' <<<"$event" || return 1

  path_line="$(
    grep -E '^type=PATH .*name=/proc/self/fd/[0-9]+ .*mode=file,200 .*obj=system_u:object_r:sysfs_t:s0' <<<"$event" |
      head -n 1
  )"
  [[ -n "$path_line" ]] || return 1

  inode="$(sed -nE 's/.* inode=([0-9]+) .*/\1/p' <<<"$path_line")"
  is_current_write_only_sysfs_uevent_inode "$inode" || return 1

  avc_count="$(grep -Ec '^type=AVC ' <<<"$event" || true)"
  [[ "$avc_count" == "2" ]] || return 1

  grep -Eq '^type=AVC .*denied[[:space:]]+\{[[:space:]]*dac_override[[:space:]]*\} .*comm="?systemd-rfkill"? .*scontext=system_u:system_r:systemd_rfkill_t:s0 .*tcontext=system_u:system_r:systemd_rfkill_t:s0 .*tclass=capability .*permissive=0' <<<"$event" || return 1
  grep -Eq '^type=AVC .*denied[[:space:]]+\{[[:space:]]*dac_read_search[[:space:]]*\} .*comm="?systemd-rfkill"? .*scontext=system_u:system_r:systemd_rfkill_t:s0 .*tcontext=system_u:system_r:systemd_rfkill_t:s0 .*tclass=capability .*permissive=0' <<<"$event" || return 1
}

audit_output=""
audit_rc=127
audit_method=""

if command -v ausearch >/dev/null 2>&1; then
  if (( EUID == 0 )); then
    audit_output="$(env LC_ALL=C LANG=C ausearch -m AVC,USER_AVC,SELINUX_ERR,USER_SELINUX_ERR -ts boot --raw 2>&1)"
    audit_rc=$?
    audit_method="ausearch"
  elif command -v sudo >/dev/null 2>&1; then
    audit_output="$(sudo env LC_ALL=C LANG=C ausearch -m AVC,USER_AVC,SELINUX_ERR,USER_SELINUX_ERR -ts boot --raw 2>&1)"
    audit_rc=$?
    audit_method="sudo ausearch"
  fi
fi

audit_authoritative=0
if (( audit_rc == 0 )); then
  audit_authoritative=1
elif (( audit_rc == 1 )) && grep -Fq '<no matches>' <<<"$audit_output"; then
  audit_authoritative=1
fi

if (( audit_authoritative )); then
  audit_records="$(
    grep -E '^type=(AVC|USER_AVC|SELINUX_ERR|USER_SELINUX_ERR)[[:space:]]' <<<"$audit_output" ||
      true
  )"

  known_execmem=0
  known_rfkill_events=0
  unexpected_avc=0
  declare -A rfkill_candidate_counts=()

  while IFS= read -r record; do
    [[ -z "$record" ]] && continue

    if is_known_syslog_ng_execmem "$record"; then
      known_execmem=$((known_execmem + 1))
      continue
    fi

    if is_systemd_rfkill_capability_candidate "$record"; then
      serial="$(audit_serial_from_record "$record")"
      if [[ -n "$serial" ]]; then
        rfkill_candidate_counts["$serial"]=$(( ${rfkill_candidate_counts["$serial"]:-0} + 1 ))
        continue
      fi
    fi

    unexpected_avc=$((unexpected_avc + 1))
  done <<<"$audit_records"

  for serial in "${!rfkill_candidate_counts[@]}"; do
    event="$(audit_event_by_serial "$serial" || true)"
    if [[ -n "$event" ]] &&
       is_known_systemd_rfkill_write_only_uevent_event "$event"; then
      known_rfkill_events=$((known_rfkill_events + 1))
    else
      unexpected_avc=$((unexpected_avc + rfkill_candidate_counts["$serial"]))
    fi
  done

  if (( unexpected_avc > 0 )); then
    warn "unexpected SELinux audit denials observed in current boot: $unexpected_avc"
  else
    if (( known_execmem > 1 )); then
      warn "documented syslog-ng/PCRE2 execmem denial repeated in current boot: $known_execmem"
    elif (( known_execmem == 1 )); then
      ok "documented syslog-ng/PCRE2 execmem denial observed once in authoritative current-boot audit evidence"
    fi

    if (( known_rfkill_events > 0 )); then
      ok "context-validated systemd-rfkill write-only sysfs uevent denials observed: $known_rfkill_events event(s)"
    fi

    if (( known_execmem == 0 && known_rfkill_events == 0 )); then
      ok "no SELinux AVC/USER_AVC denials observed in authoritative current-boot audit evidence"
    fi
  fi

  printf 'INFO: SELinux denial evidence source: %s\n' "$audit_method"
else
  if [[ -n "$audit_method" ]]; then
    warn "authoritative ausearch evidence unavailable (exit=$audit_rc); using journal fallback"
  else
    warn "authoritative ausearch tooling unavailable; using journal fallback"
  fi

  if command -v journalctl >/dev/null 2>&1 &&
     journalctl -b -n 1 --no-pager >/dev/null 2>&1; then
    avc_count="$(
      journalctl -b --no-pager -o cat 2>/dev/null |
        grep -Eic 'avc:[[:space:]]+denied' || true
    )"
    if [[ "$avc_count" =~ ^[0-9]+$ ]] && (( avc_count == 0 )); then
      printf 'INFO: journal fallback observed no current-boot AVC denials\n'
    elif [[ "$avc_count" =~ ^[0-9]+$ ]]; then
      warn "SELinux AVC denials observed in current-boot journal fallback: $avc_count"
    else
      bad "unable to evaluate current-boot SELinux AVC journal fallback"
    fi
  else
    bad "current-boot journal unavailable for SELinux AVC fallback verification"
  fi
fi

echo
echo "--- SSH SERVER ---"
check_disabled_inactive_unit() {
  local unit="$1"
  local load_state
  local active_state
  local enabled_state

  load_state="$(systemctl show -p LoadState --value "$unit" 2>/dev/null || true)"

  if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
    ok "$unit absent"
    return
  fi

  active_state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  if [[ "$active_state" == "inactive" ]]; then
    ok "$unit inactive"
  else
    bad "$unit must be inactive, found: ${active_state:-unknown}"
  fi

  enabled_state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  case "$enabled_state" in
    disabled|masked)
      ok "$unit disabled"
      ;;
    *)
      bad "$unit must be disabled or masked, found: ${enabled_state:-unknown}"
      ;;
  esac
}

if ! command -v rpm >/dev/null 2>&1; then
  bad "rpm unavailable for OpenSSH server package verification"
elif rpm -q openssh-server >/dev/null 2>&1; then
  bad "openssh-server package must be absent"
else
  ok "openssh-server package absent"
fi

if command -v systemctl >/dev/null 2>&1; then
  check_disabled_inactive_unit sshd.service
  check_disabled_inactive_unit sshd.socket
else
  bad "systemctl unavailable for SSH service verification"
fi

if command -v ss >/dev/null 2>&1; then
  if ss -ltnH 2>/dev/null |
     awk '{print $4}' |
     grep -Eq '(^|\]|:)22$'; then
    bad "TCP/22 listener present"
  else
    ok "TCP/22 listener absent"
  fi
else
  bad "ss unavailable for listener verification"
fi

echo
echo "--- KERNEL LOCKDOWN ---"
if (( is_vm )); then
  skip "kernel-lockdown physical-host check not applicable in VM"
elif [[ ! -r "$LOCKDOWN_FILE" ]]; then
  bad "kernel lockdown state unavailable: $LOCKDOWN_FILE"
else
  lockdown_state="$(cat "$LOCKDOWN_FILE" 2>/dev/null || true)"
  if grep -Eq '\[(integrity|confidentiality)\]' <<<"$lockdown_state"; then
    ok "kernel lockdown active: $lockdown_state"
  else
    bad "kernel lockdown is not active: ${lockdown_state:-unknown}"
  fi
fi

echo
echo "--- AKMOD / NVIDIA SIGNING ---"
if (( is_vm )); then
  skip "NVIDIA signer/enrollment physical-host check not applicable in VM"
elif ! command -v rpm >/dev/null 2>&1; then
  bad "rpm unavailable for NVIDIA signing verification"
elif ! rpm -q akmod-nvidia >/dev/null 2>&1; then
  skip "NVIDIA signer/enrollment check not applicable without akmod-nvidia"
else
  if [[ -r "$AKMOD_CERT" ]]; then
    ok "akmods public signing certificate available"
    if command -v mokutil >/dev/null 2>&1; then
      if mokutil --test-key "$AKMOD_CERT" >/dev/null 2>&1; then
        ok "akmods signing certificate file is enrolled in MOK"
      else
        bad "available akmods signing certificate file is not enrolled in MOK"
      fi
    else
      bad "mokutil unavailable for akmods certificate verification"
    fi
  else
    printf 'INFO: akmods certificate file not present at %s; validating the active module signer against enrolled MOK instead.\n' "$AKMOD_CERT"
  fi

  if command -v modinfo >/dev/null 2>&1; then
    nvidia_signer="$(modinfo -F signer nvidia 2>/dev/null || true)"
    nvidia_hash="$(modinfo -F sig_hashalgo nvidia 2>/dev/null || true)"

    if [[ -n "$nvidia_signer" && -n "$nvidia_hash" ]]; then
      ok "NVIDIA module signature metadata present: signer='$nvidia_signer', hash='$nvidia_hash'"
    else
      bad "NVIDIA module signature metadata incomplete"
    fi

    if [[ -n "$nvidia_signer" ]] && command -v mokutil >/dev/null 2>&1; then
      enrolled_mok="$(mokutil --list-enrolled 2>/dev/null || true)"
      if grep -Fq "$nvidia_signer" <<<"$enrolled_mok"; then
        ok "NVIDIA module signer identity is present in enrolled MOK certificates"
      else
        bad "NVIDIA module signer identity is not found in enrolled MOK certificates: $nvidia_signer"
      fi
    fi
  else
    bad "modinfo unavailable for NVIDIA signing verification"
  fi
fi

echo
echo "--- FIREWALL EXACT STATE ---"
if ! command -v firewall-cmd >/dev/null 2>&1; then
  bad "firewall-cmd unavailable"
elif ! firewall-cmd --state >/dev/null 2>&1; then
  bad "firewalld is not running"
else
  iface=""
  if command -v ip >/dev/null 2>&1; then
    iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
  fi

  if [[ -z "$iface" ]]; then
    if (( is_vm )); then
      skip "trusted Wi-Fi firewalld exact-state check not applicable in VM"
    else
      bad "default-route interface unavailable for firewalld verification"
    fi
  elif ! command -v nmcli >/dev/null 2>&1; then
    bad "nmcli unavailable for trusted Wi-Fi firewalld verification"
  else
    iface_type="$(
      nmcli -t -f DEVICE,TYPE device status 2>/dev/null |
        awk -F: -v dev="$iface" '$1 == dev { print $2; exit }'
    )"
    if [[ "$iface_type" != "wifi" ]]; then
      bad "default-route interface is not Wi-Fi: $iface (type: ${iface_type:-unknown})"
    fi

    profile="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
    saved_zone=""
    [[ -n "$profile" && "$profile" != "--" ]] &&
      saved_zone="$(nmcli -g connection.zone connection show "$profile" 2>/dev/null || true)"
    active_zone="$(firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null || true)"

    if [[ "$saved_zone" == "$ZONE" ]]; then
      ok "Wi-Fi profile persisted to $ZONE"
    else
      bad "Wi-Fi profile zone drift: expected $ZONE, found ${saved_zone:-none}"
    fi

    if [[ "$active_zone" == "$ZONE" ]]; then
      ok "active Wi-Fi interface uses $ZONE"
    else
      bad "active Wi-Fi zone drift: expected $ZONE, found ${active_zone:-none}"
    fi

    expected_services="$(printf '%s\n' dhcpv6-client mdns kdeconnect | sort)"
    runtime_services="$(
      firewall-cmd --zone="$ZONE" --list-services 2>/dev/null |
        tr ' ' '\n' |
        sed '/^$/d' |
        sort
    )"
    permanent_services="$(
      firewall-cmd --permanent --zone="$ZONE" --list-services 2>/dev/null |
        tr ' ' '\n' |
        sed '/^$/d' |
        sort
    )"

    if [[ "$runtime_services" == "$expected_services" ]]; then
      ok "runtime firewalld services match exact trusted-zone policy"
    else
      bad "runtime firewalld services differ from exact trusted-zone policy"
    fi

    if [[ "$permanent_services" == "$expected_services" ]]; then
      ok "permanent firewalld services match exact trusted-zone policy"
    else
      bad "permanent firewalld services differ from exact trusted-zone policy"
    fi

    for scope in runtime permanent; do
      scope_args=()
      [[ "$scope" == "permanent" ]] && scope_args+=(--permanent)

      if [[ "$scope" == "permanent" ]]; then
        target="$(firewall-cmd --permanent --zone="$ZONE" --get-target 2>/dev/null || true)"
      else
        target="$(
          firewall-cmd --zone="$ZONE" --list-all 2>/dev/null |
            sed -nE 's/^[[:space:]]*target:[[:space:]]*//p' |
            head -n 1
        )"
      fi

      if [[ "$target" == "default" ]]; then
        ok "$scope trusted-zone target is default"
      else
        bad "$scope trusted-zone target drift: ${target:-unknown}"
      fi

      if firewall-cmd "${scope_args[@]}" --zone="$ZONE" --query-forward >/dev/null 2>&1; then
        bad "$scope trusted-zone forwarding enabled"
      else
        ok "$scope trusted-zone forwarding disabled"
      fi

      if firewall-cmd "${scope_args[@]}" --zone="$ZONE" --query-masquerade >/dev/null 2>&1; then
        bad "$scope trusted-zone masquerade enabled"
      else
        ok "$scope trusted-zone masquerade disabled"
      fi

      if firewall-cmd "${scope_args[@]}" --zone="$ZONE" --query-icmp-block-inversion >/dev/null 2>&1; then
        bad "$scope trusted-zone ICMP block inversion enabled"
      else
        ok "$scope trusted-zone ICMP block inversion disabled"
      fi

      for option in \
        --list-ports \
        --list-protocols \
        --list-source-ports \
        --list-forward-ports \
        --list-sources \
        --list-icmp-blocks \
        --list-rich-rules; do
        extra="$(firewall-cmd "${scope_args[@]}" --zone="$ZONE" "$option" 2>/dev/null | xargs)"
        if [[ -z "$extra" ]]; then
          ok "$scope trusted-zone $option empty"
        else
          bad "$scope trusted-zone $option contains unexpected state: $extra"
        fi
      done
    done

    cross_zone_drift=0
    while IFS= read -r other_zone; do
      [[ -z "$other_zone" || "$other_zone" == "$ZONE" ]] && continue
      if firewall-cmd --permanent --zone="$other_zone" \
          --query-service=kdeconnect >/dev/null 2>&1; then
        bad "kdeconnect exposed in non-trusted permanent zone: $other_zone"
        cross_zone_drift=1
      fi
    done < <(
      firewall-cmd --permanent --get-zones 2>/dev/null |
        tr ' ' '\n' |
        sed '/^$/d'
    )
    (( cross_zone_drift == 0 )) &&
      ok "kdeconnect absent from every other permanent firewalld zone"
  fi

  echo
  echo "--- TAILSCALE FIREWALL EXACT STATE ---"

  collector_rich_rule=""
  collector_policy_valid=1

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

  if [[ -f "$SYSLOG_NG_COLLECTOR_CONF" ]]; then
    mapfile -t collector_sources < <(
      sed -nE 's/^[[:space:]]*netmask\("([0-9]{1,3}(\.[0-9]{1,3}){3}\/32)"\);[[:space:]]*$/\1/p' "$SYSLOG_NG_COLLECTOR_CONF" |
        sort -u
    )

    if (( ${#collector_sources[@]} != 1 )); then
      bad "ASUS Edge collector config must contain exactly one IPv4 /32 netmask"
      collector_policy_valid=0
    elif ! validate_tailscale_ipv4_32 "${collector_sources[0]}"; then
      bad "ASUS Edge collector source must be one Tailscale IPv4 /32"
      collector_policy_valid=0
    elif [[ ! "$SYSLOG_NG_COLLECTOR_PORT" =~ ^[0-9]+$ ]] ||
         (( 10#$SYSLOG_NG_COLLECTOR_PORT < 1 || 10#$SYSLOG_NG_COLLECTOR_PORT > 65535 )); then
      bad "ASUS Edge collector TCP port is invalid"
      collector_policy_valid=0
    else
      collector_source="${collector_sources[0]}"
      collector_rich_rule="rule family=\"ipv4\" source address=\"$collector_source\" port port=\"$SYSLOG_NG_COLLECTOR_PORT\" protocol=\"tcp\" accept"
      ok "ASUS Edge collector firewall source derived from private syslog-ng configuration"
    fi
  fi

  if ! firewall-cmd --permanent --get-zones 2>/dev/null |
      tr ' ' '\n' |
      grep -Fxq "$TAILSCALE_ZONE"; then
    bad "required Tailscale firewalld zone missing: $TAILSCALE_ZONE"
  else
    permanent_interfaces="$(
      firewall-cmd --permanent --zone="$TAILSCALE_ZONE" --list-interfaces 2>/dev/null |
        tr ' ' '\n' |
        sed '/^$/d' |
        sort
    )"
    if [[ "$permanent_interfaces" == "$TAILSCALE_IFACE" ]]; then
      ok "permanent Tailscale zone binds only $TAILSCALE_IFACE"
    else
      bad "permanent Tailscale zone interface drift: expected $TAILSCALE_IFACE, found ${permanent_interfaces:-none}"
    fi

    for scope in runtime permanent; do
      scope_args=()
      [[ "$scope" == "permanent" ]] && scope_args+=(--permanent)

      if [[ "$scope" == "permanent" ]]; then
        target="$(
          firewall-cmd --permanent --zone="$TAILSCALE_ZONE" --get-target 2>/dev/null || true
        )"
      else
        target="$(
          firewall-cmd --zone="$TAILSCALE_ZONE" --list-all 2>/dev/null |
            sed -nE 's/^[[:space:]]*target:[[:space:]]*//p' |
            head -n 1
        )"
      fi
      if [[ "$target" == "DROP" ]]; then
        ok "$scope Tailscale-zone target is DROP"
      else
        bad "$scope Tailscale-zone target drift: ${target:-unknown}"
      fi

      services="$(
        firewall-cmd "${scope_args[@]}" --zone="$TAILSCALE_ZONE" --list-services 2>/dev/null |
          xargs
      )"
      if [[ -z "$services" ]]; then
        ok "$scope Tailscale-zone services empty"
      else
        bad "$scope Tailscale-zone services contain unexpected state: $services"
      fi

      if firewall-cmd "${scope_args[@]}" --zone="$TAILSCALE_ZONE" --query-forward >/dev/null 2>&1; then
        bad "$scope Tailscale-zone forwarding enabled"
      else
        ok "$scope Tailscale-zone forwarding disabled"
      fi

      if firewall-cmd "${scope_args[@]}" --zone="$TAILSCALE_ZONE" --query-masquerade >/dev/null 2>&1; then
        bad "$scope Tailscale-zone masquerade enabled"
      else
        ok "$scope Tailscale-zone masquerade disabled"
      fi

      if firewall-cmd "${scope_args[@]}" --zone="$TAILSCALE_ZONE" --query-icmp-block-inversion >/dev/null 2>&1; then
        bad "$scope Tailscale-zone ICMP block inversion enabled"
      else
        ok "$scope Tailscale-zone ICMP block inversion disabled"
      fi

      for option in \
        --list-ports \
        --list-protocols \
        --list-source-ports \
        --list-forward-ports \
        --list-sources \
        --list-icmp-blocks; do
        extra="$(
          firewall-cmd "${scope_args[@]}" --zone="$TAILSCALE_ZONE" "$option" 2>/dev/null |
            xargs
        )"
        if [[ -z "$extra" ]]; then
          ok "$scope Tailscale-zone $option empty"
        else
          bad "$scope Tailscale-zone $option contains unexpected state: $extra"
        fi
      done

      rich_rules="$(
        firewall-cmd "${scope_args[@]}" --zone="$TAILSCALE_ZONE" --list-rich-rules 2>/dev/null |
          sed '/^$/d' |
          sort
      )"
      if (( ! collector_policy_valid )); then
        bad "$scope Tailscale-zone collector rich-rule cannot be verified from invalid private collector configuration"
      elif [[ -n "$collector_rich_rule" ]]; then
        if [[ "$rich_rules" == "$collector_rich_rule" ]]; then
          ok "$scope Tailscale-zone has only the source-restricted TCP/$SYSLOG_NG_COLLECTOR_PORT collector exception"
        else
          bad "$scope Tailscale-zone collector rich-rule drift"
        fi
      elif [[ -z "$rich_rules" ]]; then
        ok "$scope Tailscale-zone rich rules empty"
      else
        bad "$scope Tailscale-zone contains unexpected rich rules"
      fi
    done

    if command -v ip >/dev/null 2>&1 &&
       ip link show "$TAILSCALE_IFACE" >/dev/null 2>&1; then
      tailscale_active_zone="$(
        firewall-cmd --get-zone-of-interface="$TAILSCALE_IFACE" 2>/dev/null || true
      )"
      if [[ "$tailscale_active_zone" == "$TAILSCALE_ZONE" ]]; then
        ok "active Tailscale interface uses $TAILSCALE_ZONE"
      else
        bad "active Tailscale zone drift: expected $TAILSCALE_ZONE, found ${tailscale_active_zone:-none}"
      fi
    elif (( is_vm )); then
      skip "active Tailscale interface check not applicable without node identity in VM"
    else
      bad "required physical Tailscale interface missing: $TAILSCALE_IFACE"
    fi
  fi
fi

echo
echo "=== SECURITY POSTURE SUMMARY ==="
printf 'PASS=%d WARN=%d FAIL=%d SKIP=%d\n' "$pass" "$warn" "$fail" "$skip"

(( fail == 0 && warn == 0 ))
