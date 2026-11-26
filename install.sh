#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n==> %s\n' "$*"; }

usage() {
  printf '%s\n' 'Usage: install.sh [--check | --apply | --help]' \
    '  --check  Validate Fedora 44 / GNOME 50 and print the ordered plan.' \
    '  --apply  Run preflight, then apply the plan (default with no arguments).'
}

mode=--apply
if (( $# > 0 )); then
  if (( $# != 1 )); then usage >&2; exit 2; fi
  case "$1" in
    --help) usage; exit 0 ;;
    --check|--apply) mode="$1" ;;
    *) usage >&2; exit 2 ;;
  esac
fi

stages=(
  scripts/setup-repositories.sh
  scripts/install-packages.sh
  scripts/install-flatpaks.sh
  scripts/install-geforce-now.sh
  scripts/install-theme-switcher.sh
  scripts/install-ding-managed-system.sh
  scripts/install-extensions.sh
  scripts/setup-ddcutil.sh
  scripts/install-localizations.sh
  scripts/install-launchers.sh
  scripts/restore-gnome.sh
  scripts/install-weather-locations.sh
  scripts/install-dhruva-config.sh
  network/wifi-power-save.sh
  network/firewall-zone.sh
  network/tailscale-firewall-zone.sh
  system/syslog-ng-tailscale-readiness.sh
  security/disable-llmnr.sh
  security/kernel-hardening.sh
  security/disable-wsdd.sh
)

printf 'Ordered restore plan (%s stages):\n' "${#stages[@]}"
printf '  %s\n' "${stages[@]}"

if ! bash "$ROOT_DIR/scripts/install-preflight.sh" "${stages[@]}"; then
  echo "FAIL: preflight blocked restore before the first stage" >&2
  exit 1
fi
[[ "$mode" == --apply ]] || exit 0

for stage in "${stages[@]}"; do
  path="$ROOT_DIR/$stage"
  log "Running $stage"
  bash "$path"
done

log "Setup stages finished"
printf '%s\n' \
  "A GNOME sign-out/sign-in or reboot is required before final verification." \
  "After starting the new graphical session, run:" \
  "  cd $ROOT_DIR" \
  "  bash scripts/verify.sh"
