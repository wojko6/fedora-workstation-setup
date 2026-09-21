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

if command -v journalctl >/dev/null 2>&1 &&
   journalctl -b -n 1 --no-pager >/dev/null 2>&1; then
  avc_count="$(
    journalctl -b --no-pager -o cat 2>/dev/null |
      grep -Eic 'avc:[[:space:]]+denied' || true
  )"
  if [[ "$avc_count" =~ ^[0-9]+$ ]] && (( avc_count == 0 )); then
    ok "no SELinux AVC denials observed in current boot journal"
  elif [[ "$avc_count" =~ ^[0-9]+$ ]]; then
    warn "SELinux AVC denials observed in current boot journal: $avc_count"
  else
    bad "unable to evaluate current-boot SELinux AVC count"
  fi
else
  bad "current-boot journal unavailable for SELinux AVC verification"
fi

echo
echo "--- SSH SERVER ---"
check_disabled_inactive_unit() {
  local unit="$1"
  local required="$2"
  local load_state
  local active_state
  local enabled_state

  load_state="$(systemctl show -p LoadState --value "$unit" 2>/dev/null || true)"

  if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
    if [[ "$required" == "yes" ]]; then
      bad "$unit unavailable"
    else
      ok "$unit absent"
    fi
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

if command -v systemctl >/dev/null 2>&1; then
  check_disabled_inactive_unit sshd.service yes
  check_disabled_inactive_unit sshd.socket no
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
      if mokutil --list-enrolled 2>/dev/null | grep -Fq "$nvidia_signer"; then
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
  if command -v iw >/dev/null 2>&1; then
    iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')"
  fi

  if [[ -z "$iface" ]]; then
    if (( is_vm )); then
      skip "trusted Wi-Fi firewalld exact-state check not applicable in VM"
    else
      bad "physical Wi-Fi interface unavailable for firewalld verification"
    fi
  elif ! command -v nmcli >/dev/null 2>&1; then
    bad "nmcli unavailable for trusted Wi-Fi firewalld verification"
  else
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
fi

echo
echo "=== SECURITY POSTURE SUMMARY ==="
printf 'PASS=%d WARN=%d FAIL=%d SKIP=%d\n' "$pass" "$warn" "$fail" "$skip"

(( fail == 0 && warn == 0 ))
