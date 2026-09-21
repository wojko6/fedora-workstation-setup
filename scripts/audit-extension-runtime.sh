#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DESIRED="$ROOT_DIR/gnome/enabled-extensions.txt"
CANDIDATES="$ROOT_DIR/gnome/extension-candidates-lau.txt"

pass=0
warn=0
fail=0
info_count=0

ok()   { printf 'PASS: %s\n' "$*"; pass=$((pass + 1)); }
warnf(){ printf 'WARN: %s\n' "$*"; warn=$((warn + 1)); }
bad()  { printf 'FAIL: %s\n' "$*"; fail=$((fail + 1)); }
info() { printf 'INFO: %s\n' "$*"; info_count=$((info_count + 1)); }

command -v gnome-extensions >/dev/null 2>&1 || {
  echo "ERROR: gnome-extensions command is unavailable." >&2
  exit 2
}
command -v gnome-shell >/dev/null 2>&1 || {
  echo "ERROR: gnome-shell command is unavailable." >&2
  exit 2
}
[[ -f "$DESIRED" ]] || { echo "ERROR: missing $DESIRED" >&2; exit 2; }
[[ -f "$CANDIDATES" ]] || { echo "ERROR: missing $CANDIDATES" >&2; exit 2; }

shell_major="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -n1)"
[[ -n "$shell_major" ]] || shell_major="unknown"

printf '=== GNOME EXTENSION RUNTIME AUDIT ===\n'
printf 'GNOME Shell: %s\n' "$(gnome-shell --version 2>/dev/null || echo unknown)"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
printf 'User: %s\n\n' "${USER:-unknown}"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  bad "graphical-session D-Bus address is unavailable; run inside the GNOME user session"
fi

declare -A role=()
declare -A seen=()

while IFS= read -r uuid; do
  [[ -z "$uuid" || "$uuid" == \#* ]] && continue
  role["$uuid"]="desired"
  seen["$uuid"]=1
done < "$DESIRED"

while IFS= read -r uuid; do
  [[ -z "$uuid" || "$uuid" == \#* ]] && continue
  if [[ -z "${role[$uuid]:-}" ]]; then
    role["$uuid"]="candidate"
  fi
  seen["$uuid"]=1
done < "$CANDIDATES"

while IFS= read -r uuid; do
  [[ -z "$uuid" ]] && continue
  if [[ -z "${role[$uuid]:-}" ]]; then
    role["$uuid"]="other"
  fi
  seen["$uuid"]=1
done < <(gnome-extensions list 2>/dev/null || true)

printf '%-11s %-7s %-8s %-7s %s\n' "ROLE" "RESULT" "STATE" "GNOME" "UUID"
printf '%-11s %-7s %-8s %-7s %s\n' "-----------" "-------" "--------" "-------" "----"

mapfile -t uuids < <(printf '%s\n' "${!seen[@]}" | sort)

for uuid in "${uuids[@]}"; do
  this_role="${role[$uuid]:-other}"
  ext_info="$(gnome-extensions info "$uuid" 2>/dev/null || true)"

  if [[ -z "$ext_info" ]]; then
    if [[ "$this_role" == "desired" ]]; then
      result="FAIL"
      state="MISSING"
      fail=$((fail + 1))
    elif [[ "$this_role" == "candidate" ]]; then
      result="WARN"
      state="MISSING"
      warn=$((warn + 1))
    else
      result="INFO"
      state="MISSING"
      info_count=$((info_count + 1))
    fi
    printf '%-11s %-7s %-8s %-7s %s\n' "$this_role" "$result" "$state" "?" "$uuid"
    continue
  fi

  state="$(sed -nE 's/^[[:space:]]*(State|Stan):[[:space:]]*//p' <<<"$ext_info" | head -n1)"
  [[ -n "$state" ]] || state="UNKNOWN"

  ext_dir=""
  if [[ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]]; then
    ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
  elif [[ -d "/usr/share/gnome-shell/extensions/$uuid" ]]; then
    ext_dir="/usr/share/gnome-shell/extensions/$uuid"
  fi

  compat="?"
  if [[ -n "$ext_dir" && -f "$ext_dir/metadata.json" && "$shell_major" != "unknown" ]]; then
    if grep -Eq "\"${shell_major}\"" "$ext_dir/metadata.json"; then
      compat="yes"
    else
      compat="no"
    fi
  fi

  case "$state" in
    ACTIVE)
      if [[ "$this_role" == "desired" || "$this_role" == "candidate" ]]; then
        result="PASS"
        pass=$((pass + 1))
      else
        result="INFO"
        info_count=$((info_count + 1))
      fi
      ;;
    ERROR)
      result="FAIL"
      fail=$((fail + 1))
      ;;
    *)
      if [[ "$this_role" == "desired" ]]; then
        result="FAIL"
        fail=$((fail + 1))
      elif [[ "$this_role" == "candidate" ]]; then
        result="WARN"
        warn=$((warn + 1))
      else
        result="INFO"
        info_count=$((info_count + 1))
      fi
      ;;
  esac

  if [[ "$compat" == "no" && "$result" == "PASS" ]]; then
    result="WARN"
    pass=$((pass - 1))
    warn=$((warn + 1))
  fi

  printf '%-11s %-7s %-8s %-7s %s\n' "$this_role" "$result" "$state" "$compat" "$uuid"
done

printf '\n=== CONFLICT CHECKS ===\n'
dhruva_state="$(gnome-extensions info dhruva@narkagni 2>/dev/null | sed -nE 's/^[[:space:]]*(State|Stan):[[:space:]]*//p' | head -n1)"
dash2dock_state="$(gnome-extensions info dash2dock-lite@icedman.github.com 2>/dev/null | sed -nE 's/^[[:space:]]*(State|Stan):[[:space:]]*//p' | head -n1)"

if [[ "$dhruva_state" == "ACTIVE" && "$dash2dock_state" == "ACTIVE" ]]; then
  bad "Dhruva and Dash2Dock Animated are active simultaneously (duplicate dock conflict)"
elif [[ "$dhruva_state" == "ACTIVE" ]]; then
  ok "Dhruva is the active canonical dock; Dash2Dock Animated is not active"
else
  warnf "Dhruva is not ACTIVE (state=${dhruva_state:-missing})"
fi

printf '\n=== GSCONNECT HEALTH ===\n'
if gnome-extensions info gsconnect@andyholmes.github.io >/dev/null 2>&1; then
  gs_state="$(gnome-extensions info gsconnect@andyholmes.github.io 2>/dev/null | sed -nE 's/^[[:space:]]*(State|Stan):[[:space:]]*//p' | head -n1)"
  if [[ "$gs_state" == "ACTIVE" ]]; then
    ok "GSConnect shell extension is ACTIVE"
  else
    bad "GSConnect shell extension state is ${gs_state:-unknown}"
  fi

  if command -v busctl >/dev/null 2>&1 && busctl --user list 2>/dev/null | grep -Fq 'org.gnome.Shell.Extensions.GSConnect'; then
    ok "GSConnect D-Bus service is registered"
  else
    bad "GSConnect D-Bus service is not registered"
  fi

  if command -v gdbus >/dev/null 2>&1 && gdbus introspect --session \
      --dest org.gnome.Shell.Extensions.GSConnect \
      --object-path /org/gnome/Shell/Extensions/GSConnect >/dev/null 2>&1; then
    ok "GSConnect D-Bus service responds to introspection"
  else
    bad "GSConnect D-Bus service does not respond"
  fi

  if command -v firewall-cmd >/dev/null 2>&1 &&
     command -v ip >/dev/null 2>&1 &&
     command -v nmcli >/dev/null 2>&1; then
    wifi_iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
    wifi_type=""
    if [[ -n "$wifi_iface" ]]; then
      wifi_type="$(
        nmcli -t -f DEVICE,TYPE device status 2>/dev/null |
          awk -F: -v dev="$wifi_iface" '$1 == dev { print $2; exit }'
      )"
    fi

    if [[ -n "$wifi_iface" && "$wifi_type" == "wifi" ]]; then
      zone="$(firewall-cmd --get-zone-of-interface="$wifi_iface" 2>/dev/null || true)"
      if [[ -n "$zone" && "$(firewall-cmd --zone="$zone" --query-service=kdeconnect 2>/dev/null || true)" == "yes" ]]; then
        ok "KDE Connect service allowed in active default-route Wi-Fi firewalld zone: $zone"
      else
        bad "KDE Connect service is not allowed in active default-route Wi-Fi zone (${zone:-unknown})"
      fi
    else
      warnf "default-route Wi-Fi interface unavailable for GSConnect firewall audit"
    fi
  else
    warnf "firewalld/ip/nmcli unavailable for GSConnect firewall audit"
  fi
else
  warnf "GSConnect is not installed"
fi

printf '\n=== NOTES ===\n'
info "Dash2Dock Animated is intentionally excluded because Dhruva is the canonical dock"
info "Android KDE Connect may bypass Tailscale via app-based split tunneling; phone-side policy is intentionally outside Fedora desired state"

printf '\n=== EXTENSION AUDIT SUMMARY ===\n'
printf 'PASS=%d WARN=%d FAIL=%d INFO=%d\n' "$pass" "$warn" "$fail" "$info_count"

if (( fail > 0 )); then
  exit 1
fi
exit 0
