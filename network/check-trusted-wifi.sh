#!/usr/bin/env bash
# Standalone read-only check. When sourced by firewall-zone.sh, a VM skip
# exits the stage and a match supplies iface, PROFILE and TRUSTED_UUID.
set -Eeuo pipefail

TRUSTED_UUID="${TRUSTED_WIFI_UUID:-}"
EXPECTED_PROFILE="${TRUSTED_WIFI_PROFILE:-}"

wifi_fail() {
  echo "FAIL: $*" >&2
  return 1
}

virt="none"
if command -v systemd-detect-virt >/dev/null 2>&1; then
  virt="$(systemd-detect-virt 2>/dev/null || true)"
  [[ -n "$virt" ]] || virt="none"
fi

if [[ -n "$EXPECTED_PROFILE" && -z "$TRUSTED_UUID" ]]; then
  wifi_fail "TRUSTED_WIFI_PROFILE requires a reviewed TRUSTED_WIFI_UUID"
fi

if [[ -z "$TRUSTED_UUID" && "$virt" != "none" ]]; then
  echo "SKIP: trusted Wi-Fi firewalld policy is not applied in virtualized environment: $virt"
  exit 0
fi

[[ -n "$TRUSTED_UUID" ]] || wifi_fail \
  "TRUSTED_WIFI_UUID is required; refusing to trust the active/default-route network implicitly."

if [[ ! "$TRUSTED_UUID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
  wifi_fail "TRUSTED_WIFI_UUID is not a valid NetworkManager UUID"
fi

iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
[[ -n "$iface" ]] || wifi_fail "default-route interface unavailable; firewall zone not changed."

active_profile="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
active_uuid="$(nmcli -g GENERAL.CON-UUID device show "$iface" 2>/dev/null || true)"
iface_type="$(
  nmcli -t -f DEVICE,TYPE device status 2>/dev/null |
    awk -F: -v dev="$iface" '$1 == dev { print $2; exit }'
)"

[[ -n "$active_profile" && "$active_profile" != "--" ]] ||
  wifi_fail "NetworkManager profile unavailable for default-route interface"
[[ -n "$active_uuid" && "$active_uuid" != "--" ]] ||
  wifi_fail "NetworkManager UUID unavailable for default-route interface"
[[ "$iface_type" == "wifi" ]] ||
  wifi_fail "default-route interface is not Wi-Fi"

if [[ "$active_uuid" != "$TRUSTED_UUID" ]]; then
  wifi_fail "active Wi-Fi profile is not trusted"
fi

if [[ -n "$EXPECTED_PROFILE" && "$active_profile" != "$EXPECTED_PROFILE" ]]; then
  wifi_fail "trusted Wi-Fi profile name mismatch"
fi

PROFILE="$active_profile"
profile_uuid="$(nmcli -g connection.uuid connection show "$PROFILE" 2>/dev/null || true)"
profile_type="$(nmcli -g connection.type connection show "$PROFILE" 2>/dev/null || true)"

[[ "$profile_uuid" == "$TRUSTED_UUID" ]] ||
  wifi_fail "profile UUID changed during preflight"
[[ "$profile_type" == "802-11-wireless" ]] ||
  wifi_fail "trusted NetworkManager profile is not Wi-Fi"

echo "PASS: default-route Wi-Fi matches the reviewed profile and UUID"
