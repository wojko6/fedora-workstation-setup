#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RPM_MANIFEST="$ROOT_DIR/packages/rpm.txt"
RPM_ABSENT_MANIFEST="$ROOT_DIR/packages/rpm-absent.txt"
FLATPAK_MANIFEST="$ROOT_DIR/packages/flatpak.txt"
EXT_LIST="$ROOT_DIR/gnome/enabled-extensions.txt"
EXT_INVENTORY="$ROOT_DIR/gnome/extensions-inventory.tsv"
EXT_TREE_LOCK="$ROOT_DIR/gnome/extensions-tree-lock.tsv"
EXT_TREE_HELPER="$ROOT_DIR/scripts/extension_tree_integrity.py"

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
      bad "required rpm missing: $pkg"
    fi
  done < "$RPM_MANIFEST"
else
  bad "missing $RPM_MANIFEST"
fi

echo
echo "=== RPM ABSENT MANIFEST ==="
if [[ -f "$RPM_ABSENT_MANIFEST" ]]; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if rpm -q "$pkg" >/dev/null 2>&1; then
      bad "excluded rpm installed: $pkg"
    else
      ok "excluded rpm absent: $pkg"
    fi
  done < "$RPM_ABSENT_MANIFEST"
else
  bad "missing $RPM_ABSENT_MANIFEST"
fi

echo
echo "=== EXTERNAL REPOSITORIES ==="
HELIUM_REPO_ID="copr:copr.fedorainfracloud.org:imput:helium"
VPCS_REPO_ID="copr:copr.fedorainfracloud.org:tgerov:vpcs"
repo_ids="$(dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}')"
for repo in rpmfusion-free rpmfusion-nonfree brave-browser "$HELIUM_REPO_ID"; do
  if grep -Fxq "$repo" <<<"$repo_ids"; then
    ok "repo $repo"
  else
    bad "required repo not enabled: $repo"
  fi
done

if grep -Fxq "$VPCS_REPO_ID" <<<"$repo_ids"; then
  ok "repo VPCS COPR (tgerov/vpcs)"
else
  bad "required VPCS COPR repository not enabled: tgerov/vpcs"
fi

REPOSITORY_TRUST_VERIFY="$ROOT_DIR/scripts/verify-repository-trust.py"
if [[ ! -f "$REPOSITORY_TRUST_VERIFY" ]]; then
  bad "external repository trust verifier missing"
elif repository_trust_output="$(python3 "$REPOSITORY_TRUST_VERIFY" 2>&1)"; then
  printf '%s\n' "$repository_trust_output"
  ok "external repository trust policy matches reviewed configuration"
else
  printf '%s\n' "$repository_trust_output"
  bad "external repository trust policy verification failed"
fi

echo
echo "=== TAILSCALE ==="
if command -v tailscale >/dev/null 2>&1 && rpm -q tailscale >/dev/null 2>&1; then
  ok "Tailscale client installed"
  if systemctl is-enabled tailscaled >/dev/null 2>&1; then
    ok "tailscaled service enabled"
  else
    bad "tailscaled service is not enabled"
  fi
  if systemctl is-active tailscaled >/dev/null 2>&1; then
    ok "tailscaled service active"
  else
    bad "tailscaled service is not active"
  fi
else
  bad "Tailscale client missing"
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
echo "=== EXPLICIT SECURITY POSTURE ==="
SECURITY_POSTURE_VERIFY="$ROOT_DIR/scripts/verify-security-posture.sh"
if [[ ! -f "$SECURITY_POSTURE_VERIFY" ]]; then
  bad "explicit security posture verifier missing"
else
  security_posture_output="$(bash "$SECURITY_POSTURE_VERIFY" 2>&1)"
  security_posture_rc=$?
  printf '%s\n' "$security_posture_output"
  if (( security_posture_rc == 0 )); then
    ok "explicit security posture verification passed"
  else
    bad "explicit security posture verification failed"
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
iface=""
default_iface=""
if command -v ip >/dev/null 2>&1; then
  default_iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
fi

if [[ -n "$default_iface" ]] && command -v nmcli >/dev/null 2>&1; then
  default_iface_type="$(
    nmcli -t -f DEVICE,TYPE device status 2>/dev/null |
      awk -F: -v dev="$default_iface" '$1 == dev { print $2; exit }'
  )"
  if [[ "$default_iface_type" == "wifi" ]]; then
    iface="$default_iface"
  elif (( ! is_vm )); then
    bad "default-route interface is not Wi-Fi: $default_iface (type: ${default_iface_type:-unknown})"
  fi
fi

if [[ -n "$iface" ]]; then
  printf 'Interface: %s\n' "$iface"
  ps="$(iw dev "$iface" get power_save 2>/dev/null || true)"
  printf '%s\n' "$ps"
  if grep -qi 'off' <<<"$ps"; then ok "Wi-Fi power save disabled"; else bad "Wi-Fi power save is not confirmed off"; fi
elif (( is_vm )); then
  skip "Wi-Fi hardware check not applicable in VM"
elif [[ -z "$default_iface" ]]; then
  bad "default-route interface unavailable"
elif ! command -v nmcli >/dev/null 2>&1; then
  bad "nmcli unavailable for Wi-Fi interface verification"
fi

echo
echo "=== WIFI FIREWALL ZONE ==="
if [[ -n "${iface:-}" ]]; then
  wifi_profile="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"

  if [[ -n "$wifi_profile" && "$wifi_profile" != "--" ]]; then
    saved_zone="$(nmcli -g connection.zone connection show "$wifi_profile" 2>/dev/null || true)"

    expected_zone="workstation-kdeconnect"

    if [[ "$saved_zone" == "$expected_zone" ]]; then
      ok "Wi-Fi NetworkManager profile uses dedicated firewalld zone $expected_zone"
    else
      bad "Wi-Fi NetworkManager profile firewalld zone: expected $expected_zone, found ${saved_zone:-none}"
    fi

    active_zone="$(firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null || true)"

    if [[ "$active_zone" == "$expected_zone" ]]; then
      ok "active Wi-Fi interface uses dedicated firewalld zone $expected_zone"
    else
      bad "active Wi-Fi interface firewalld zone: expected $expected_zone, found ${active_zone:-none}"
    fi

    if firewall-cmd --zone="$expected_zone" --query-service=kdeconnect >/dev/null 2>&1; then
      ok "KDE Connect enabled in dedicated firewalld zone $expected_zone"
    else
      bad "KDE Connect missing from dedicated firewalld zone $expected_zone"
    fi

    if firewall-cmd --zone=public --query-service=kdeconnect >/dev/null 2>&1; then
      bad "KDE Connect remains enabled in shared firewalld zone public"
    else
      ok "KDE Connect absent from shared firewalld zone public"
    fi
  else
    bad "Active Wi-Fi NetworkManager profile unavailable"
  fi
elif (( is_vm )); then
  skip "Wi-Fi firewall-zone checks not applicable in VM"
else
  bad "No Wi-Fi interface detected for firewall-zone checks"
fi

echo
echo "=== FLATPAK APPS ==="
if [[ ! -f "$FLATPAK_MANIFEST" ]]; then
  bad "missing $FLATPAK_MANIFEST"
elif ! command -v flatpak >/dev/null 2>&1; then
  bad "flatpak command unavailable"
else
  if flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq flathub; then
    ok "system Flatpak remote flathub available"
  else
    bad "required system Flatpak remote missing: flathub"
  fi

  while IFS= read -r app; do
    [[ -z "$app" || "$app" == \#* ]] && continue
    if flatpak --system info "$app" >/dev/null 2>&1; then
      ok "system flatpak $app"
    else
      bad "required system Flatpak app missing: $app"
    fi
  done < "$FLATPAK_MANIFEST"
fi

echo
echo "=== GNOME DESIRED STATE ==="
if [[ -x "$ROOT_DIR/scripts/audit-gnome.sh" || -f "$ROOT_DIR/scripts/audit-gnome.sh" ]]; then
  gnome_audit="$(bash "$ROOT_DIR/scripts/audit-gnome.sh" 2>&1 || true)"
  gnome_summary="$(grep -Eo 'PASS=[0-9]+ WARN=[0-9]+' <<<"$gnome_audit" | tail -n 1)"
  if [[ "$gnome_summary" =~ ^PASS=([0-9]+)\ WARN=([0-9]+)$ ]]; then
    gnome_pass="${BASH_REMATCH[1]}"; gnome_warn="${BASH_REMATCH[2]}"
    if (( gnome_warn == 0 )); then ok "GNOME desired state matches (${gnome_pass} checks)"; else bad "GNOME desired state has ${gnome_warn} mismatch(es)"; fi
  else bad "GNOME audit summary unavailable"; fi
else bad "scripts/audit-gnome.sh missing"; fi

echo
echo "=== GNOME WEATHER CUSTOM LOCATIONS ==="
WEATHER_MANAGER="$ROOT_DIR/scripts/manage-weather-locations.py"
WEATHER_CONFIG="$ROOT_DIR/gnome/weather-locations.local.tsv"
if [[ ! -f "$WEATHER_MANAGER" ]]; then
  bad "GNOME Weather location manager missing"
elif [[ ! -f "$WEATHER_CONFIG" ]]; then
  printf 'INFO: private GNOME Weather location config not present; no private location check requested\n'
elif weather_verify_output="$(python3 "$WEATHER_MANAGER" --config "$WEATHER_CONFIG" --verify 2>&1)"; then
  printf '%s\n' "$weather_verify_output"
  ok "GNOME Weather private custom locations match local desired state"
else
  printf '%s\n' "$weather_verify_output"
  bad "GNOME Weather private custom locations missing or drifted"
fi

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
echo "=== GSCONNECT POLISH LOCALIZATION ==="
if gsconnect_verify_output="$(bash "$ROOT_DIR/scripts/verify-gsconnect-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$gsconnect_verify_output"; then
    skip "GSConnect Polish localization: extension not installed"
  else
    ok "GSConnect v73 Polish localization and Shell gettext domain match repository"
  fi
else
  printf '%s\n' "$gsconnect_verify_output"
  bad "GSConnect Polish localization missing, incomplete, or differs"
fi

echo
echo "=== TILING SHELL POLISH LOCALIZATION ==="
if tiling_verify_output="$(bash "$ROOT_DIR/scripts/verify-tiling-shell-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$tiling_verify_output"; then
    skip "Tiling Shell Polish localization: extension not installed"
  else
    ok "Tiling Shell 17.3 Polish localization matches repository completion"
  fi
else
  printf '%s\n' "$tiling_verify_output"
  bad "Tiling Shell Polish localization missing, incomplete, or differs"
fi

echo
echo "=== JUST PERFECTION POLISH LOCALIZATION ==="
if just_perfection_verify_output="$(bash "$ROOT_DIR/scripts/verify-just-perfection-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$just_perfection_verify_output"; then
    skip "Just Perfection Polish localization: extension not installed"
  else
    ok "Just Perfection v37 Polish localization matches repository"
  fi
else
  printf '%s\n' "$just_perfection_verify_output"
  bad "Just Perfection Polish localization missing, incomplete, or differs"
fi

echo
echo "=== SPOTLIGHT POLISH LOCALIZATION ==="
if spotlight_verify_output="$(bash "$ROOT_DIR/scripts/verify-spotlight-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$spotlight_verify_output"; then
    skip "Spotlight Polish localization: extension not installed"
  else
    ok "Spotlight v15 / 2026.15 Polish localization matches repository"
  fi
else
  printf '%s\n' "$spotlight_verify_output"
  bad "Spotlight Polish localization missing, incomplete, or differs"
fi

echo
echo "=== SPACE BAR POLISH LOCALIZATION ==="
if space_bar_verify_output="$(bash "$ROOT_DIR/scripts/verify-space-bar-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$space_bar_verify_output"; then
    skip "Space Bar Polish localization: extension not installed"
  else
    ok "Space Bar v39 Polish localization matches repository"
  fi
else
  printf '%s\n' "$space_bar_verify_output"
  bad "Space Bar Polish localization missing, incomplete, or differs"
fi

echo
echo "=== ARCMENU POLISH LOCALIZATION ==="
if arcmenu_verify_output="$(bash "$ROOT_DIR/scripts/verify-arcmenu-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$arcmenu_verify_output"; then
    skip "ArcMenu Polish localization: extension not installed"
  else
    ok "ArcMenu v73 / 69.2 Polish gettext binding fix matches repository"
  fi
else
  printf '%s\n' "$arcmenu_verify_output"
  bad "ArcMenu Polish localization missing, incomplete, or differs"
fi

echo
echo "=== BLUETOOTH BATTERY METER POLISH LOCALIZATION ==="
if bluetooth_battery_verify_output="$(bash "$ROOT_DIR/scripts/verify-bluetooth-battery-meter-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$bluetooth_battery_verify_output"; then
    skip "Bluetooth Battery Meter Polish localization: extension not installed"
  else
    ok "Bluetooth Battery Meter v46/v49 BudsLink Polish localization matches repository completion"
  fi
else
  printf '%s\n' "$bluetooth_battery_verify_output"
  bad "Bluetooth Battery Meter BudsLink Polish localization missing, incomplete, or differs"
fi

echo
echo "=== CLIPBOARD INDICATOR POLISH LOCALIZATION ==="
if clipboard_verify_output="$(bash "$ROOT_DIR/scripts/verify-clipboard-indicator-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$clipboard_verify_output"; then
    skip "Clipboard Indicator Polish localization: extension not installed"
  else
    ok "Clipboard Indicator v71 Polish localization matches repository completion"
  fi
else
  printf '%s\n' "$clipboard_verify_output"
  bad "Clipboard Indicator Polish localization missing, incomplete, or differs"
fi

echo
echo "=== BLUR MY SHELL POLISH LOCALIZATION ==="
if blur_verify_output="$(bash "$ROOT_DIR/scripts/verify-blur-my-shell-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$blur_verify_output"; then
    skip "Blur my Shell Polish localization: extension not installed"
  else
    ok "Blur my Shell v72 Polish localization matches repository completion"
  fi
else
  printf '%s\n' "$blur_verify_output"
  bad "Blur my Shell Polish localization missing, incomplete, or differs"
fi

echo
echo "=== VITALS POLISH LOCALIZATION ==="
if vitals_verify_output="$(bash "$ROOT_DIR/scripts/verify-vitals-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$vitals_verify_output"; then
    skip "Vitals Polish localization: extension not installed"
  else
    ok "Vitals v85 Polish localization matches repository completion"
  fi
else
  printf '%s\n' "$vitals_verify_output"
  bad "Vitals Polish localization missing, incomplete, or differs"
fi

echo
echo "=== DDTERM POLISH LOCALIZATION ==="
if ddterm_verify_output="$(bash "$ROOT_DIR/scripts/verify-ddterm-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$ddterm_verify_output"; then
    skip "ddterm Polish localization: extension not installed"
  else
    ok "ddterm v73 Polish localization and metadata description match repository"
  fi
else
  printf '%s\n' "$ddterm_verify_output"
  bad "ddterm Polish localization missing, incomplete, or differs"
fi

echo
echo "=== ADVANCED MEDIA CONTROLLER POLISH LOCALIZATION ==="
if amc_verify_output="$(bash "$ROOT_DIR/scripts/verify-advanced-media-controller-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$amc_verify_output"; then
    skip "Advanced Media Controller Polish localization: extension not installed"
  else
    ok "Advanced Media Controller v31 / 6.5 Polish localization matches repository"
  fi
else
  printf '%s\n' "$amc_verify_output"
  bad "Advanced Media Controller Polish localization missing, incomplete, or differs"
fi

echo
echo "=== DHRUVA POLISH LOCALIZATION ==="

DHRUVA_EXT="$HOME/.local/share/gnome-shell/extensions/dhruva@narkagni"
DHRUVA_PO="$ROOT_DIR/localization/dhruva/pl.po"
DHRUVA_PATCH_DIR="$ROOT_DIR/patches/gnome-extensions/dhruva"
DHRUVA_GENERATOR="$ROOT_DIR/scripts/generate-dhruva-emoji-pl.py"
DHRUVA_MO="$DHRUVA_EXT/locale/pl/LC_MESSAGES/dhruva.mo"
DHRUVA_EMOJI="$DHRUVA_EXT/src/ui/folder-menu/emoji-pl.js"

if [[ ! -d "$DHRUVA_EXT" ]]; then
  skip "Dhruva Polish localization: extension not installed"
elif ! command -v msgfmt >/dev/null 2>&1; then
  bad "Dhruva Polish localization: msgfmt unavailable"
elif ! command -v python3 >/dev/null 2>&1; then
  bad "Dhruva Polish localization: python3 unavailable"
elif [[ ! -f "$DHRUVA_PO" ||
        ! -x "$DHRUVA_GENERATOR" ||
        ! -d "$DHRUVA_PATCH_DIR" ]]; then
  bad "Dhruva Polish localization: repository sources incomplete"
else
  dhruva_tmp="$(mktemp -d)"
  dhruva_ok=1

  if ! msgfmt --check "$DHRUVA_PO" \
      -o "$dhruva_tmp/dhruva.mo" >/dev/null 2>&1; then
    dhruva_ok=0
  fi

  dhruva_patch_count="$(
    find "$DHRUVA_PATCH_DIR" -maxdepth 1 \
      -type f -name '*.patch' | wc -l
  )"

  if [[ "$dhruva_patch_count" -ne 20 ]]; then
    dhruva_ok=0
  fi

  if [[ ! -f "$DHRUVA_MO" ]] ||
     ! cmp -s "$dhruva_tmp/dhruva.mo" "$DHRUVA_MO"; then
    dhruva_ok=0
  fi

  if ! grep -q '"gettext-domain"[[:space:]]*:[[:space:]]*"dhruva"' \
      "$DHRUVA_EXT/metadata.json"; then
    dhruva_ok=0
  fi

  if ! grep -q "_('Monitor %s')" \
      "$DHRUVA_EXT/src/prefs/LayoutPage.js"; then
    dhruva_ok=0
  fi

  if ! grep -q "_('Window')" \
      "$DHRUVA_EXT/src/ui/context-menu/WindowThumbnailBuilder.js"; then
    dhruva_ok=0
  fi

  if ! grep -q 'emojiPl' \
      "$DHRUVA_EXT/src/ui/folder-menu/EmojiPicker.js"; then
    dhruva_ok=0
  fi

  if ! python3 "$DHRUVA_GENERATOR" \
      --source "$DHRUVA_EXT/src/ui/emojis.js" \
      --output "$dhruva_tmp/emoji-pl.js" >/dev/null 2>&1; then
    dhruva_ok=0
  fi

  if [[ ! -f "$DHRUVA_EMOJI" ]] ||
     ! cmp -s "$dhruva_tmp/emoji-pl.js" "$DHRUVA_EMOJI"; then
    dhruva_ok=0
  fi

  if [[ -f "$dhruva_tmp/emoji-pl.js" ]]; then
    dhruva_emoji_count="$(
      grep -c '^  "' "$dhruva_tmp/emoji-pl.js"
    )"
    if [[ "$dhruva_emoji_count" -ne 1907 ]]; then
      dhruva_ok=0
    fi
  else
    dhruva_ok=0
  fi

  rm -rf "$dhruva_tmp"

  if (( dhruva_ok )); then
    ok "Dhruva Polish localization matches repository (20 patches, 1907 CLDR emoji)"
  else
    bad "Dhruva Polish localization missing, incomplete, or differs"
  fi
fi

echo
echo "=== BACKGROUND LOGO POLISH LOCALIZATION ==="

BG_LOGO_PREFS="/usr/share/gnome-shell/extensions/background-logo@fedorahosted.org/prefs.js"

if [[ ! -f "$BG_LOGO_PREFS" ]]; then
  skip "Background Logo extension not installed"
elif grep -q "Pokazuj na wszystkich tłach" "$BG_LOGO_PREFS" &&
     grep -q "Nazwa pliku (tryb ciemny)" "$BG_LOGO_PREFS" &&
     grep -q "Lewy dolny róg" "$BG_LOGO_PREFS" &&
     grep -q "Krycie" "$BG_LOGO_PREFS"; then
  ok "Background Logo Polish localization installed"
else
  bad "Background Logo Polish localization missing or differs"
fi

echo
echo "=== BROWSER SWITCHER POLISH LOCALIZATION ==="

BS_DIR="$HOME/.local/share/gnome-shell/extensions/browser-switcher@totoshko88.github.io"
BS_MENU="$BS_DIR/menuBuilder.js"
BS_INDICATOR="$BS_DIR/indicator.js"

if [[ ! -d "$BS_DIR" ]]; then
  skip "Browser Switcher extension not installed"
elif [[ ! -f "$BS_MENU" || ! -f "$BS_INDICATOR" ]]; then
  bad "Browser Switcher localization target files missing"
elif grep -Fq "Nie znaleziono przeglądarek" "$BS_MENU" &&
     grep -Fq "Nie udało się zmienić domyślnej przeglądarki." "$BS_MENU" &&
     grep -Fq "Wskaźnik Browser Switcher" "$BS_INDICATOR"; then
  ok "Browser Switcher Polish localization installed"
else
  bad "Browser Switcher Polish localization missing or differs"
fi

echo
echo "=== PAPERS / NAUTILUS POLISH LOCALIZATION ==="
PAPERS_VERIFY="$ROOT_DIR/scripts/verify-papers-localization.sh"
if [[ ! -x "$PAPERS_VERIFY" ]]; then
  bad "Papers localization verifier missing or not executable"
elif "$PAPERS_VERIFY"; then
  ok "Papers / Nautilus document-properties localization matches repository"
else
  bad "Papers / Nautilus document-properties localization missing or differs"
fi

echo
echo "=== PLYMOUTH POLISH LOCALIZATION ==="
PLYMOUTH_VERIFY="$ROOT_DIR/scripts/verify-plymouth-localization.sh"
if [[ ! -x "$PLYMOUTH_VERIFY" ]]; then
  bad "Plymouth localization verifier missing or not executable"
elif "$PLYMOUTH_VERIFY"; then
  ok "Plymouth Polish offline-update localization state matches repository"
else
  bad "Plymouth Polish offline-update localization state missing or differs"
fi

echo
echo "=== EXTENSION MANAGER POLISH LOCALIZATION ==="
if extension_manager_verify_output="$(bash "$ROOT_DIR/scripts/verify-extension-manager-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$extension_manager_verify_output"; then
    skip "Extension Manager Polish localization: Flatpak not installed"
  else
    ok "Extension Manager 0.6.5 Polish localization matches repository completion"
  fi
else
  printf '%s\n' "$extension_manager_verify_output"
  bad "Extension Manager Polish localization missing, incomplete, or differs"
fi

echo
echo "=== HELIUM POLISH LOCALIZATION ==="
if helium_verify_output="$(bash "$ROOT_DIR/scripts/verify-helium-localization.sh" 2>&1)"; then
  ok "Helium Polish localization matches repository"
else
  printf '%s\n' "$helium_verify_output"
  bad "Helium Polish localization missing, incomplete, or differs"
fi

echo
echo "=== GNOME TWEAKS POLISH LOCALIZATION ==="
if gnome_tweaks_verify_output="$(bash "$ROOT_DIR/scripts/verify-gnome-tweaks-localization.sh" 2>&1)"; then
  if grep -q '^SKIP:' <<<"$gnome_tweaks_verify_output"; then
    skip "GNOME Tweaks Polish localization: application not installed"
  else
    ok "GNOME Tweaks 49.0 generated GSettings labels and Polish completion match repository"
  fi
else
  printf '%s\n' "$gnome_tweaks_verify_output"
  bad "GNOME Tweaks Polish localization missing, incomplete, or differs"
fi

echo
echo "=== PTYXIS POLISH LOCALIZATION ==="
PTYXIS_VERIFY="$ROOT_DIR/scripts/verify-ptyxis-localization.sh"
if [[ ! -f "$PTYXIS_VERIFY" ]]; then
  bad "Ptyxis localization verifier missing"
elif bash "$PTYXIS_VERIFY"; then
  ok "Ptyxis 50.1 Polish main-window localization matches repository"
else
  bad "Ptyxis 50.1 Polish main-window localization missing or differs"
fi

echo
echo "=== DING SYSTEM MONITOR MENU ==="
DING_SYSTEM_MONITOR_VERIFY="$ROOT_DIR/scripts/verify-ding-system-monitor-menu.sh"
if [[ ! -f "$DING_SYSTEM_MONITOR_VERIFY" ]]; then
  bad "DING System Monitor menu verifier missing"
elif bash "$DING_SYSTEM_MONITOR_VERIFY"; then
  ok "DING System Monitor desktop-menu integration matches repository"
else
  bad "DING System Monitor desktop-menu integration missing or drifted"
fi

echo
echo "=== DESKTOP LAUNCHERS ==="
if [[ -f "$HOME/Pulpit/Counter-Strike 2.desktop" ]]; then ok "desktop launcher: Counter-Strike 2.desktop"; else warn "desktop launcher missing: Counter-Strike 2.desktop"; fi
ASUS_CONF="$ROOT_DIR/desktop/launchers/asus-router.conf"
ASUS_TEMPLATE="$ROOT_DIR/desktop/launchers/asus-router.desktop.template"
ASUS_RENDERER="$ROOT_DIR/scripts/render-asus-launcher.py"
if [[ -f "$ASUS_CONF" ]]; then
  ASUS_LAUNCHER="$HOME/Pulpit/asus-router.desktop"
  ASUS_APP_LAUNCHER="$HOME/.local/share/applications/asus-router.desktop"
  DDTERM_BIN="$HOME/.local/share/gnome-shell/extensions/ddterm@amezin.github.com/bin/com.github.amezin.ddterm"

  if [[ ! -f "$ASUS_RENDERER" || ! -f "$ASUS_TEMPLATE" ]]; then
    bad "ASUS launcher renderer/template missing"
  elif ! command -v python3 >/dev/null 2>&1; then
    bad "python3 unavailable for ASUS launcher verification"
  else
    asus_expected="$(mktemp)"
    if python3 "$ASUS_RENDERER" \
        --config "$ASUS_CONF" \
        --template "$ASUS_TEMPLATE" \
        --ddterm-bin "$DDTERM_BIN" \
        --output "$asus_expected" \
        --check-key-file; then
      ok "private ASUS launcher configuration parses safely as data"

      if [[ -f "$ASUS_LAUNCHER" ]] && cmp -s "$asus_expected" "$ASUS_LAUNCHER"; then
        ok "desktop launcher: asus-router.desktop matches rendered desired state"
      else
        bad "desktop ASUS launcher missing or differs from rendered desired state"
      fi

      if [[ -f "$ASUS_APP_LAUNCHER" ]] && cmp -s "$asus_expected" "$ASUS_APP_LAUNCHER"; then
        ok "application launcher: asus-router.desktop matches rendered desired state"
      else
        bad "application ASUS launcher missing or differs from rendered desired state"
      fi
    else
      bad "private ASUS launcher configuration is invalid or unsafe"
    fi
    rm -f "$asus_expected"
  fi
else
  printf 'INFO: private ASUS launcher configuration intentionally absent from public repository\n'
  if [[ -f "$HOME/Pulpit/asus-router.desktop" ]]; then
    printf 'INFO: local-only ASUS launcher exists and is intentionally outside repository verification\n'
  else
    printf 'INFO: ASUS launcher not managed without private configuration\n'
  fi
fi

echo
echo "=== DHRUVA DOCK STATE ==="

DHRUVA_DESIRED="$ROOT_DIR/gnome/dhruva/dock-state.json"
DHRUVA_STATE="$HOME/.config/dhruva@narkagni/dhruva-dock-items.json"

if [[ ! -f "$DHRUVA_DESIRED" ]]; then
  bad "Dhruva repository dock state missing"
elif [[ ! -f "$DHRUVA_STATE" ]]; then
  bad "Dhruva live dock state missing"
elif ! command -v python3 >/dev/null 2>&1; then
  bad "Dhruva dock state: python3 unavailable"
elif python3 - "$DHRUVA_DESIRED" "$DHRUVA_STATE" <<'PYVERIFY'
import json
import sys
from pathlib import Path

desired = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
actual = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

if not isinstance(desired, dict) or not isinstance(actual, dict):
    raise SystemExit(1)

if actual.get("order") != desired.get("order"):
    raise SystemExit(1)

if actual.get("folders") != desired.get("folders"):
    raise SystemExit(1)

raise SystemExit(0)
PYVERIFY
then
  ok "Dhruva dock state matches repository"
else
  bad "Dhruva dock state differs from repository"
fi

echo
echo "=== EXTENSION VERSIONS ==="
if [[ -f "$EXT_INVENTORY" ]]; then
  while IFS=$'\t' read -r uuid name expected_version _shell_versions _url location; do
    [[ "$uuid" == "uuid" || -z "$uuid" || -z "$expected_version" ]] && continue
    [[ "${location#\~}" != '/.local/'* ]] && continue
    ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"; metadata="$ext_dir/metadata.json"
    if [[ ! -f "$metadata" ]]; then bad "required extension metadata missing: $uuid"; continue; fi
    current="$(gnome-extensions info "$uuid" 2>/dev/null | sed -nE 's/^[[:space:]]*(Version|Wersja):[[:space:]]*//p' | head -n 1)"
    if [[ -z "$current" ]]; then
      bad "required extension version unavailable: $uuid"
    elif [[ "$current" == "$expected_version" || "$current" =~ \("$expected_version"\)$ ]]; then
      ok "extension version $uuid = $expected_version"
    else
      bad "extension version $uuid: expected $expected_version, found $current"
    fi
  done < "$EXT_INVENTORY"
else bad "extension inventory missing"; fi

echo
echo "=== EXTENSION TREE INTEGRITY ==="
if [[ ! -f "$EXT_TREE_LOCK" ]]; then
  bad "extension tree-integrity lock missing"
elif [[ ! -f "$EXT_TREE_HELPER" ]]; then
  bad "extension tree-integrity helper missing"
elif [[ ! -f "$EXT_INVENTORY" || ! -f "$EXT_LIST" ]]; then
  bad "extension inventory or enabled list unavailable for tree-integrity verification"
else
  tree_integrity_output="$(
    python3 "$EXT_TREE_HELPER" verify       --lock "$EXT_TREE_LOCK"       --inventory "$EXT_INVENTORY"       --enabled "$EXT_LIST"       --extensions-root "$HOME/.local/share/gnome-shell/extensions"       2>&1
  )"
  tree_integrity_rc=$?
  printf '%s\n' "$tree_integrity_output"

  if (( tree_integrity_rc == 0 )); then
    ok "all required user-extension trees match accepted integrity lock"
  else
    bad "GNOME extension tree integrity verification failed"
  fi
fi

echo
echo "=== GNOME KEYRING I18N ==="

KEYRING_VERIFY="$ROOT_DIR/scripts/verify-gnome-keyring-i18n.sh"

if [[ ! -x "$KEYRING_VERIFY" ]]; then
  bad "GNOME Keyring i18n verifier missing or not executable"
elif "$KEYRING_VERIFY"; then
  ok "GNOME Keyring i18n verification passed"
else
  bad "GNOME Keyring i18n verification failed"
fi
echo
echo "=== RECOVERY READINESS ==="
if [[ -d "$ROOT_DIR/docs" ]]; then
  ok "documentation directory available"
else
  bad "documentation directory missing"
fi

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "repository integrity available"
else
  bad "repository metadata unavailable"
fi

if [[ -f "$ROOT_DIR/PROJECT-STATUS.md" ]]; then
  ok "project status documentation available"
else
  bad "PROJECT-STATUS.md missing"
fi
echo
echo "=== SUMMARY ==="
printf 'PASS=%d WARN=%d FAIL=%d SKIP=%d\n' "$pass" "$warn" "$fail" "$skip"
(( fail == 0 && warn == 0 ))
