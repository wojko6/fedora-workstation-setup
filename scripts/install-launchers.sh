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
ASUS_RENDERER="$ROOT_DIR/scripts/render_asus_launcher.py"
if [[ -f "$ASUS_CONF" ]]; then
  command -v python3 >/dev/null 2>&1 || {
    printf 'ERROR: python3 is required to render the ASUS launcher.\n' >&2
    exit 1
  }
  [[ -f "$ASUS_RENDERER" ]] || {
    printf 'ERROR: ASUS launcher renderer missing: %s\n' "$ASUS_RENDERER" >&2
    exit 1
  }

  DDTERM_BIN="$HOME/.local/share/gnome-shell/extensions/ddterm@amezin.github.com/bin/com.github.amezin.ddterm"

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  python3 "$ASUS_RENDERER" \
    --config "$ASUS_CONF" \
    --template "$ASUS_TEMPLATE" \
    --ddterm-bin "$DDTERM_BIN" \
    --output "$tmp"

  install_launcher "$tmp" "asus-router.desktop"
else
  printf 'SKIP: ASUS launcher config not found: %s\n' "$ASUS_CONF"
  printf '      Copy asus-router.conf.example to asus-router.conf and fill in local values.\n'
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi
