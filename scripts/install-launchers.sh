#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHERS_DIR="$ROOT_DIR/desktop/launchers"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="${XDG_DESKTOP_DIR:-$HOME/Pulpit}"

mkdir -p "$APPS_DIR" "$DESKTOP_DIR"

install_launcher() {
  local src="$1"
  local name="$2"
  install -m 0644 "$src" "$APPS_DIR/$name"
  install -m 0644 "$src" "$DESKTOP_DIR/$name"
  printf 'INSTALLED: %s\n' "$name"
}

# Counter-Strike 2 contains no private workstation data.
install_launcher "$LAUNCHERS_DIR/counter-strike-2.desktop" "Counter-Strike 2.desktop"

# ASUS SSH launcher is rendered only when a local, gitignored config exists.
ASUS_CONF="$LAUNCHERS_DIR/asus-router.conf"
ASUS_TEMPLATE="$LAUNCHERS_DIR/asus-router.desktop.template"
if [[ -f "$ASUS_CONF" ]]; then
  # shellcheck disable=SC1090
  source "$ASUS_CONF"
  : "${SSH_KEY:?SSH_KEY is required in $ASUS_CONF}"
  : "${SSH_PORT:?SSH_PORT is required in $ASUS_CONF}"
  : "${SSH_USER:?SSH_USER is required in $ASUS_CONF}"
  : "${ROUTER_HOST:?ROUTER_HOST is required in $ASUS_CONF}"

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  sed \
    -e "s|__SSH_KEY__|$SSH_KEY|g" \
    -e "s|__SSH_PORT__|$SSH_PORT|g" \
    -e "s|__SSH_USER__|$SSH_USER|g" \
    -e "s|__ROUTER_HOST__|$ROUTER_HOST|g" \
    "$ASUS_TEMPLATE" > "$tmp"
  install_launcher "$tmp" "asus-router.desktop"
else
  printf 'SKIP: ASUS launcher config not found: %s\n' "$ASUS_CONF"
  printf '      Copy asus-router.conf.example to asus-router.conf and fill in local values.\n'
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi
