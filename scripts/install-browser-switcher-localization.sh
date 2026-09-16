#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="browser-switcher@totoshko88.github.io"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
PATCH_DIR="$ROOT_DIR/patches/gnome-extensions/browser-switcher"

install_patch() {
    local file="$1"
    local patch_file="$2"
    local marker="$3"

    local target="$EXT_DIR/$file"
    local patch_path="$PATCH_DIR/$patch_file"
    local backup="$target.pre-polish.bak"

    if [[ ! -f "$target" ]]; then
        echo "SKIP: Browser Switcher file not found: $file"
        return 0
    fi

    if [[ ! -f "$patch_path" ]]; then
        echo "FAIL: patch not found: $patch_path" >&2
        return 1
    fi

    if grep -Fq "$marker" "$target"; then
        echo "PASS: $file already localized"
        return 0
    fi

    if ! patch --dry-run --silent "$target" "$patch_path"; then
        echo "FAIL: patch is incompatible with current $file" >&2
        return 1
    fi

    if [[ ! -e "$backup" ]]; then
        cp -a "$target" "$backup"
        echo "PASS: backup created: $file.pre-polish.bak"
    fi

    patch --silent "$target" "$patch_path"

    if grep -Fq "$marker" "$target"; then
        echo "PASS: localized $file"
    else
        echo "FAIL: localization verification failed: $file" >&2
        return 1
    fi
}

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Browser Switcher is not installed"
    exit 0
fi

echo "=== BROWSER SWITCHER POLISH LOCALIZATION ==="

install_patch \
    "menuBuilder.js" \
    "menuBuilder-pl.patch" \
    "Nie znaleziono przeglądarek"

install_patch \
    "indicator.js" \
    "indicator-pl.patch" \
    "Wskaźnik Browser Switcher"
