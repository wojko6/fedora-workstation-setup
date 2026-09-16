#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RPM_MANIFEST="$ROOT_DIR/packages/rpm.txt"
EXT_LIST="$ROOT_DIR/gnome/enabled-extensions.txt"

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

is_vm_host_only_pkg() {
  case "$1" in
    VirtualBox|akmod-VirtualBox|akmod-nvidia|xorg-x11-drv-nvidia-cuda) return 0 ;;
    *) return 1 ;;
  esac
}

echo "=== SYSTEM ==="
if [[ -r /etc/fedora-release ]]; then
  cat /etc/fedora-release
  ok "Fedora release detected"
else
  bad "/etc/fedora-release missing"
fi

gnome-shell --version 2>/dev/null || warn "GNOME Shell version unavailable"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
printf 'Virtualization: %s\n' "$virt"
if (( is_vm )); then
  ok "virtualized test environment detected: $virt"
else
  ok "physical host environment detected"
fi

echo
echo "=== RPM MANIFEST ==="
if [[ -f "$RPM_MANIFEST" ]]; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if rpm -q "$pkg" >/dev/null 2>&1; then
      ok "rpm $pkg"
    elif (( is_vm )) && is_vm_host_only_pkg "$pkg"; then
      skip "host-only rpm not required in VM: $pkg"
    else
      warn "rpm missing: $pkg"
    fi
  done < "$RPM_MANIFEST"
else
  bad "missing $RPM_MANIFEST"
fi

echo
echo "=== EXTERNAL REPOSITORIES ==="
repo_ids="$(dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}')"
for repo in rpmfusion-free rpmfusion-nonfree brave-browser repo.nordvpn.com_yum_nordvpn_centos_x86_64; do
  if grep -Fxq "$repo" <<<"$repo_ids"; then
    ok "repo $repo"
  else
    warn "repo not enabled: $repo"
  fi
done

echo
echo "=== TAILSCALE ==="
if command -v tailscale >/dev/null 2>&1 && rpm -q tailscale >/dev/null 2>&1; then
  ok "Tailscale client installed"
  if systemctl is-enabled tailscaled >/dev/null 2>&1; then
    ok "tailscaled service enabled"
  else
    warn "tailscaled service is not enabled"
  fi
  if systemctl is-active tailscaled >/dev/null 2>&1; then
    ok "tailscaled service active"
  else
    warn "tailscaled service is not active"
  fi
else
  warn "Tailscale client missing"
fi

echo
echo "=== SECURITY HARDENING ==="
LLMNR_CONF="/etc/systemd/resolved.conf.d/10-disable-llmnr.conf"
if [[ -f "$LLMNR_CONF" ]] && grep -Eq '^[[:space:]]*LLMNR[[:space:]]*=[[:space:]]*no[[:space:]]*$' "$LLMNR_CONF"; then
  ok "systemd-resolved LLMNR disabled in persistent configuration"
else
  bad "systemd-resolved LLMNR hardening missing"
fi
if command -v resolvectl >/dev/null 2>&1 && resolvectl status 2>/dev/null | grep -q 'Protocols: -LLMNR'; then
  ok "LLMNR disabled at runtime"
else
  bad "LLMNR runtime state is not confirmed disabled"
fi
if ss -ltn 2>/dev/null | awk 'NR > 1 {print $4}' | grep -Eq '(^|\]|:)5355$'; then
  bad "TCP/5355 listener present"
else
  ok "TCP/5355 listener absent"
fi

KPTR_CONF="/etc/sysctl.d/60-workstation-hardening.conf"
if [[ -f "$KPTR_CONF" ]] && grep -Eq '^[[:space:]]*kernel\.kptr_restrict[[:space:]]*=[[:space:]]*1[[:space:]]*$' "$KPTR_CONF"; then
  ok "kernel.kptr_restrict=1 in persistent configuration"
else
  bad "kernel pointer hardening configuration missing"
fi
if [[ "$(sysctl -n kernel.kptr_restrict 2>/dev/null)" == "1" ]]; then
  ok "kernel.kptr_restrict=1 at runtime"
else
  bad "kernel.kptr_restrict runtime state is not 1"
fi

if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas 2>/dev/null | grep -Fxq 'org.gnome.system.wsdd'; then
  if [[ "$(gsettings get org.gnome.system.wsdd display-mode 2>/dev/null)" == "'disabled'" ]]; then
    ok "GNOME/GVfs WSDD discovery disabled"
  else
    bad "GNOME/GVfs WSDD discovery is not disabled"
  fi
else
  bad "GNOME/GVfs WSDD schema unavailable"
fi
if ss -lun 2>/dev/null | awk 'NR > 1 {print $5}' | grep -Eq '(^|\]|:)3702$'; then
  bad "UDP/3702 WSDD listener present"
else
  ok "UDP/3702 WSDD listener absent"
fi

echo
echo "=== SECURE BOOT ==="
if (( is_vm )); then
  skip "Secure Boot physical-host check not applicable in VM"
  skip "NVIDIA module-signing physical-host check not applicable in VM"
else
  if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -Fqi 'SecureBoot enabled'; then
    ok "Secure Boot enabled"
  else
    bad "Secure Boot is not confirmed enabled"
  fi

  if rpm -q akmod-nvidia >/dev/null 2>&1; then
    nvidia_signer="$(modinfo -F signer nvidia 2>/dev/null || true)"
    nvidia_hash="$(modinfo -F sig_hashalgo nvidia 2>/dev/null || true)"
    if [[ -n "$nvidia_signer" && -n "$nvidia_hash" ]]; then
      ok "NVIDIA kernel module is signed (${nvidia_hash})"
    else
      bad "NVIDIA kernel module signature is not confirmed"
    fi
  else
    skip "NVIDIA module-signing check not applicable without akmod-nvidia"
  fi
fi

echo
echo "=== GNOME EXTENSIONS ==="
if command -v gnome-extensions >/dev/null 2>&1; then
  if [[ -f "$EXT_LIST" ]]; then
    while IFS= read -r uuid; do
      [[ -z "$uuid" || "$uuid" == \#* ]] && continue
      if gnome-extensions info "$uuid" >/dev/null 2>&1; then
        ok "extension installed: $uuid"
        state="$(gnome-extensions info "$uuid" 2>/dev/null | sed -nE 's/^[[:space:]]*(State|Stan):[[:space:]]*//p' | head -n 1)"
        if [[ "$state" == "ACTIVE" ]]; then ok "extension runtime active: $uuid"; else bad "required extension runtime state $uuid: ${state:-unknown}"; fi
        ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
        schema_dir="$ext_dir/schemas"
        if [[ -d "$schema_dir" ]] && compgen -G "$schema_dir/*.gschema.xml" >/dev/null; then
          if [[ -f "$schema_dir/gschemas.compiled" ]]; then ok "extension schemas compiled: $uuid"; else bad "required extension schemas not compiled: $uuid"; fi
        fi
      else
        bad "required extension missing: $uuid"
      fi
    done < "$EXT_LIST"
  else
    bad "missing $EXT_LIST"
  fi
else
  bad "gnome-extensions command unavailable"
fi

echo
echo "=== WIFI POWER SAVE ==="
iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')"
if [[ -n "$iface" ]]; then
  printf 'Interface: %s\n' "$iface"
  ps="$(iw dev "$iface" get power_save 2>/dev/null || true)"
  printf '%s\n' "$ps"
  if grep -qi 'off' <<<"$ps"; then ok "Wi-Fi power save disabled"; else warn "Wi-Fi power save is not confirmed off"; fi
elif (( is_vm )); then skip "Wi-Fi hardware check not applicable in VM"; else warn "No Wi-Fi interface detected"; fi

echo
echo "=== WIFI FIREWALL ZONE ==="
if [[ -n "${iface:-}" ]]; then
  wifi_profile="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"

  if [[ -n "$wifi_profile" && "$wifi_profile" != "--" ]]; then
    saved_zone="$(nmcli -g connection.zone connection show "$wifi_profile" 2>/dev/null || true)"

    if [[ "$saved_zone" == "public" ]]; then
      ok "Wi-Fi NetworkManager profile uses firewalld zone public"
    else
      bad "Wi-Fi NetworkManager profile firewalld zone is not public"
    fi

    active_zone="$(firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null || true)"

    if [[ "$active_zone" == "public" ]]; then
      ok "active Wi-Fi interface uses firewalld zone public"
    else
      bad "active Wi-Fi interface firewalld zone is not public"
    fi
  else
    warn "Active Wi-Fi NetworkManager profile unavailable"
  fi
elif (( is_vm )); then
  skip "Wi-Fi firewall-zone checks not applicable in VM"
else
  warn "No Wi-Fi interface detected for firewall-zone checks"
fi

echo
echo "=== FLATPAK APPS ==="
if command -v flatpak >/dev/null 2>&1; then flatpak list --app --columns=application 2>/dev/null || true; else warn "flatpak command unavailable"; fi

echo
echo "=== GNOME DESIRED STATE ==="
if [[ -x "$ROOT_DIR/scripts/audit-gnome.sh" || -f "$ROOT_DIR/scripts/audit-gnome.sh" ]]; then
  gnome_audit="$(bash "$ROOT_DIR/scripts/audit-gnome.sh" 2>&1 || true)"
  gnome_summary="$(grep -Eo 'PASS=[0-9]+ WARN=[0-9]+' <<<"$gnome_audit" | tail -n 1)"
  if [[ "$gnome_summary" =~ ^PASS=([0-9]+)\ WARN=([0-9]+)$ ]]; then
    gnome_pass="${BASH_REMATCH[1]}"; gnome_warn="${BASH_REMATCH[2]}"
    if (( gnome_warn == 0 )); then ok "GNOME desired state matches (${gnome_pass} checks)"; else warn "GNOME desired state has ${gnome_warn} mismatch(es)"; fi
  else warn "GNOME audit summary unavailable"; fi
else warn "scripts/audit-gnome.sh missing"; fi

echo
echo "=== POLISH LOCALIZATIONS ==="

verify_translation() {
  local name="$1"
  local uuid="$2"
  local domain="$3"

  local source_po="$ROOT_DIR/localization/$name/pl.po"
  local ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
  local target_mo="$ext_dir/locale/pl/LC_MESSAGES/$domain.mo"

  if [[ ! -d "$ext_dir" ]]; then
    skip "Polish localization: extension not installed: $uuid"
    return
  fi

  if [[ ! -f "$source_po" ]]; then
    bad "Polish localization source missing: $name"
    return
  fi

  if ! command -v msgfmt >/dev/null 2>&1; then
    bad "msgfmt unavailable for Polish localization verification"
    return
  fi

  local tmp_mo
  tmp_mo="$(mktemp)"

  if ! msgfmt --check "$source_po" -o "$tmp_mo" 2>/dev/null; then
    rm -f "$tmp_mo"
    bad "Polish localization failed msgfmt validation: $name"
    return
  fi

  if [[ -f "$target_mo" ]] && cmp -s "$tmp_mo" "$target_mo"; then
    ok "Polish localization matches repository: $uuid"
  else
    bad "Polish localization differs or is missing: $uuid"
  fi

  rm -f "$tmp_mo"
}

verify_translation \
  "ding" \
  "ding@rastersoft.com" \
  "ding"

verify_translation \
  "display-brightness-ddcutil" \
  "display-brightness-ddcutil@themightydeity.github.com" \
  "display-brightness-ddcutil"

verify_translation \
  "just-another-search-bar" \
  "just-another-search-bar@xelad0m" \
  "just-another-search-bar"

verify_translation \
  "monitor-smart-saver" \
  "monitorSmartSaver@pic16f877ccs.github.com" \
  "monitor-smart-saver"

echo
echo "=== DESKTOP LAUNCHERS ==="
if [[ -f "$HOME/Pulpit/Counter-Strike 2.desktop" ]]; then ok "desktop launcher: Counter-Strike 2.desktop"; else warn "desktop launcher missing: Counter-Strike 2.desktop"; fi
ASUS_CONF="$ROOT_DIR/desktop/launchers/asus-router.conf"
if [[ -f "$ASUS_CONF" ]]; then
  ok "private ASUS launcher configuration available"
  if [[ -f "$HOME/Pulpit/asus-router.desktop" ]]; then ok "desktop launcher: asus-router.desktop"; else warn "private ASUS config exists but desktop launcher is missing"; fi
else
  skip "private ASUS launcher configuration intentionally absent"
  if [[ -f "$HOME/Pulpit/asus-router.desktop" ]]; then warn "ASUS launcher exists without repository private configuration"; else skip "ASUS launcher not expected without private configuration"; fi
fi

echo
echo "=== EXTENSION VERSIONS ==="
EXT_INVENTORY="$ROOT_DIR/gnome/extensions-inventory.tsv"
if [[ -f "$EXT_INVENTORY" ]]; then
  while IFS=$'\t' read -r uuid name expected_version shell_versions url location; do
    [[ "$uuid" == "uuid" || -z "$uuid" || -z "$expected_version" ]] && continue
    [[ "$location" != "~/.local/"* ]] && continue
    ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"; metadata="$ext_dir/metadata.json"
    if [[ ! -f "$metadata" ]]; then bad "required extension metadata missing: $uuid"; continue; fi
    current="$(gnome-extensions info "$uuid" 2>/dev/null | sed -nE 's/^[[:space:]]*(Version|Wersja):[[:space:]]*//p' | head -n 1)"
    case "$uuid:$expected_version" in
      dhruva@narkagni:16)
        metadata_version="$(sed -nE 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*([0-9]+),?[[:space:]]*$/\1/p' "$metadata" | head -n 1)"
        metadata_name="$(sed -nE 's/^[[:space:]]*"version-name"[[:space:]]*:[[:space:]]*"([^"]+)"[,]?[[:space:]]*$/\1/p' "$metadata" | head -n 1)"
        if [[ "$metadata_version" == "17" && "$metadata_name" == "2.0" ]]; then ok "extension archive $uuid = EGO v16 (metadata 2.0/17)"; else bad "extension archive $uuid: expected EGO v16 metadata 2.0/17, found ${metadata_name:-?}/${metadata_version:-?}"; fi ;;
      *)
        if [[ -z "$current" ]]; then bad "required extension version unavailable: $uuid"; elif [[ "$current" == "$expected_version" || "$current" =~ \("$expected_version"\)$ ]]; then ok "extension version $uuid = $expected_version"; else bad "extension version $uuid: expected $expected_version, found $current"; fi ;;
    esac
  done < "$EXT_INVENTORY"
else bad "extension inventory missing"; fi

echo
echo "=== SUMMARY ==="
printf 'PASS=%d WARN=%d FAIL=%d SKIP=%d\n' "$pass" "$warn" "$fail" "$skip"
(( fail == 0 ))
