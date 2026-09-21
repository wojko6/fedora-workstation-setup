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
# The config is parsed as a strict KEY=value data file and is never sourced.
ASUS_CONF="$LAUNCHERS_DIR/asus-router.conf"
ASUS_TEMPLATE="$LAUNCHERS_DIR/asus-router.desktop.template"
ASUS_RENDERER="$ROOT_DIR/scripts/render-asus-launcher.py"

if [[ -f "$ASUS_CONF" ]]; then
  command -v python3 >/dev/null 2>&1 || {
    echo "ERROR: python3 is required to render the ASUS launcher." >&2
    exit 1
  }

  for path in "$ASUS_TEMPLATE" "$ASUS_RENDERER"; do
    [[ -f "$path" ]] || {
      echo "ERROR: required ASUS launcher source missing: $path" >&2
      exit 1
    }
  done

  DDTERM_BIN="$HOME/.local/share/gnome-shell/extensions/ddterm@amezin.github.com/bin/com.github.amezin.ddterm"
  if [[ ! -x "$DDTERM_BIN" ]]; then
    printf 'ERROR: ddterm command not found or not executable: %s\n' "$DDTERM_BIN" >&2
    exit 1
  fi

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  python3 "$ASUS_RENDERER" \
    --config "$ASUS_CONF" \
    --template "$ASUS_TEMPLATE" \
    --ddterm-bin "$DDTERM_BIN" \
    --output "$tmp" \
    --check-key-file

  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$tmp"
  fi

  install_launcher "$tmp" "asus-router.desktop"
else
  printf 'SKIP: ASUS launcher config not found: %s\n' "$ASUS_CONF"
  printf '      Copy asus-router.conf.example to asus-router.conf and fill in local values.\n'
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi
