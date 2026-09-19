#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n==> %s\n' "$*"; }

if [[ ! -r /etc/fedora-release ]]; then
  echo "ERROR: This setup is intended for Fedora." >&2
  exit 1
fi

EXPECTED_FEDORA="44"
EXPECTED_GNOME_MAJOR="50"

fedora_version="$(rpm -E %fedora)"
if [[ "$fedora_version" != "$EXPECTED_FEDORA" ]]; then
  echo "ERROR: supported Fedora version is $EXPECTED_FEDORA, found $fedora_version." >&2
  exit 1
fi

if ! command -v gnome-shell >/dev/null 2>&1; then
  echo "ERROR: gnome-shell is required." >&2
  exit 1
fi

gnome_version="$(gnome-shell --version 2>/dev/null)"

if [[ "$gnome_version" =~ ([0-9]+)(\.[0-9]+)* ]]; then
  gnome_major="${BASH_REMATCH[1]}"
else
  echo "ERROR: unable to determine GNOME Shell version from: $gnome_version" >&2
  exit 1
fi

if [[ "$gnome_major" != "$EXPECTED_GNOME_MAJOR" ]]; then
  echo "ERROR: supported GNOME major is $EXPECTED_GNOME_MAJOR, found ${gnome_major:-unknown}." >&2
  exit 1
fi

log "Fedora workstation setup"
cat /etc/fedora-release
printf 'Validated baseline: Fedora %s / GNOME %s\n' \
  "$fedora_version" "$gnome_version"

stages=(
  scripts/setup-repositories.sh
  scripts/install-packages.sh
  scripts/install-flatpaks.sh
  scripts/install-extensions.sh
  scripts/setup-ddcutil.sh
  scripts/install-localizations.sh
  scripts/install-launchers.sh
  scripts/restore-gnome.sh
  scripts/install-dhruva-config.sh
  network/wifi-power-save.sh
  network/firewall-zone.sh
  security/disable-llmnr.sh
  security/kernel-hardening.sh
  security/disable-wsdd.sh
)

for stage in "${stages[@]}"; do
  path="$ROOT_DIR/$stage"
  if [[ -f "$path" ]]; then
    log "Running $stage"
    bash "$path"
  else
    printf 'SKIP: %s is not implemented yet.\n' "$stage"
  fi
done

log "Setup stages finished"
printf '%s\n' \
  "A GNOME sign-out/sign-in or reboot is required before final verification." \
  "After starting the new graphical session, run:" \
  "  cd $ROOT_DIR" \
  "  bash scripts/verify.sh"
