#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n==> %s\n' "$*"; }

if [[ ! -r /etc/fedora-release ]]; then
  echo "ERROR: This setup is intended for Fedora." >&2
  exit 1
fi

log "Fedora workstation setup"
cat /etc/fedora-release

stages=(
  scripts/setup-repositories.sh
  scripts/install-packages.sh
  scripts/install-flatpaks.sh
  scripts/install-extensions.sh
  scripts/restore-gnome.sh
  network/wifi-power-save.sh
  scripts/verify.sh
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
