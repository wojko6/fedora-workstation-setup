#!/usr/bin/env bash
set -Eeuo pipefail

CONF_FILE="/etc/sysctl.d/60-workstation-hardening.conf"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

printf 'Configuring kernel hardening: kernel.kptr_restrict=1\n'
printf '# Fedora workstation security hardening\nkernel.kptr_restrict = 1\n' | \
  "${SUDO[@]}" tee "$CONF_FILE" >/dev/null
"${SUDO[@]}" sysctl -p "$CONF_FILE" >/dev/null

printf 'Kernel hardening applied.\n'
