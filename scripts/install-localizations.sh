#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALIZATION_DIR="$ROOT_DIR/localization"

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "FAIL: msgfmt not found (install gettext)" >&2
    exit 1
fi

install_translation() {
    local name="$1"
    local uuid="$2"
    local domain="$3"

    local source_po="$LOCALIZATION_DIR/$name/pl.po"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    local locale_dir="$ext_dir/locale/pl/LC_MESSAGES"
    local target_mo="$locale_dir/$domain.mo"

    echo
    echo "=== POLISH LOCALIZATION: $name ==="

    if [[ ! -d "$ext_dir" ]]; then
        echo "SKIP: extension not installed: $uuid"
        return 0
    fi

    if [[ ! -f "$source_po" ]]; then
        echo "FAIL: missing translation source: $source_po" >&2
        return 1
    fi

    echo "Validating pl.po..."
    msgfmt --check "$source_po" -o /dev/null

    mkdir -p "$locale_dir"

    local tmp_mo
    tmp_mo="$(mktemp)"
    trap 'rm -f "$tmp_mo"' RETURN

    msgfmt "$source_po" -o "$tmp_mo"

    if [[ -f "$target_mo" ]] && cmp -s "$tmp_mo" "$target_mo"; then
        echo "PASS: Polish translation already installed: $uuid"
        return 0
    fi

    if [[ -f "$target_mo" ]]; then
        local backup="${target_mo}.upstream.bak"

        if [[ ! -f "$backup" ]]; then
            cp -a "$target_mo" "$backup"
            echo "Backup: $backup"
        fi
    fi

    install -m 0644 "$tmp_mo" "$target_mo"

    if cmp -s "$tmp_mo" "$target_mo"; then
        echo "PASS: Polish translation installed: $uuid"
    else
        echo "FAIL: installed translation verification failed: $uuid" >&2
        return 1
    fi
}

install_translation \
    "ding" \
    "ding@rastersoft.com" \
    "ding"

install_translation \
    "display-brightness-ddcutil" \
    "display-brightness-ddcutil@themightydeity.github.com" \
    "display-brightness-ddcutil"

install_translation \
    "just-another-search-bar" \
    "just-another-search-bar@xelad0m" \
    "just-another-search-bar"

install_translation \
    "monitor-smart-saver" \
    "monitorSmartSaver@pic16f877ccs.github.com" \
    "monitor-smart-saver"

echo
echo "=== POLISH LOCALIZATION: Background Logo ==="
bash "$ROOT_DIR/scripts/install-background-logo-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Browser Switcher ==="
bash "$ROOT_DIR/scripts/install-browser-switcher-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Dhruva ==="
bash "$ROOT_DIR/scripts/install-dhruva-localization.sh"

echo
echo "=== POLISH LOCALIZATION: GSConnect completion ==="
bash "$ROOT_DIR/scripts/install-gsconnect-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Tiling Shell completion ==="
bash "$ROOT_DIR/scripts/install-tiling-shell-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Just Perfection v37 ==="
bash "$ROOT_DIR/scripts/install-just-perfection-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Spotlight v15 / 2026.15 ==="
bash "$ROOT_DIR/scripts/install-spotlight-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Space Bar v39 ==="
bash "$ROOT_DIR/scripts/install-space-bar-localization.sh"

echo
echo "=== POLISH LOCALIZATION: ArcMenu v73 / 69.2 ==="
bash "$ROOT_DIR/scripts/install-arcmenu-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Bluetooth Battery Meter v46/v49 BudsLink completion ==="
bash "$ROOT_DIR/scripts/install-bluetooth-battery-meter-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Clipboard Indicator v71 completion ==="
bash "$ROOT_DIR/scripts/install-clipboard-indicator-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Blur my Shell v72 completion ==="
bash "$ROOT_DIR/scripts/install-blur-my-shell-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Vitals v85 completion ==="
bash "$ROOT_DIR/scripts/install-vitals-localization.sh"

echo
echo "=== POLISH LOCALIZATION: ddterm v72 completion ==="
bash "$ROOT_DIR/scripts/install-ddterm-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Advanced Media Controller v31 / 6.5 ==="
bash "$ROOT_DIR/scripts/install-advanced-media-controller-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Papers / Nautilus document properties ==="
bash "$ROOT_DIR/scripts/install-papers-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Plymouth offline updates ==="
bash "$ROOT_DIR/scripts/install-plymouth-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Ptyxis 50.1 / libadwaita About dialog ==="
bash "$ROOT_DIR/scripts/install-ptyxis-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Extension Manager 0.6.5 Flatpak ==="
bash "$ROOT_DIR/scripts/install-extension-manager-localization.sh"

echo
echo "=== POLISH LOCALIZATION: Helium browser ==="
bash "$ROOT_DIR/scripts/install-helium-localization.sh"

echo
echo "Custom Polish localizations complete."
