#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR="/etc/systemd/resolved.conf.d"
CONF_FILE="$CONF_DIR/10-disable-llmnr.conf"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

printf 'Configuring systemd-resolved: LLMNR=no\n'
"${SUDO[@]}" mkdir -p "$CONF_DIR"
printf '[Resolve]\nLLMNR=no\n' | "${SUDO[@]}" tee "$CONF_FILE" >/dev/null
"${SUDO[@]}" systemctl restart systemd-resolved

printf 'LLMNR hardening applied.\n'
