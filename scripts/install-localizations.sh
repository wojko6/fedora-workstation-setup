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

echo
echo "Custom Polish localizations complete."
