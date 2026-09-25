#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
CONSTANTS_TARGET="$EXT_DIR/constants.js"
MENU_WIDGETS_TARGET="$EXT_DIR/menuWidgets.js"
BACKUP_DIR="$EXT_DIR/.localization-backup-v73"
CONSTANTS_BACKUP="$BACKUP_DIR/constants.js"
MENU_WIDGETS_BACKUP="$BACKUP_DIR/menuWidgets.js"

BIND_PATCH="$ROOT_DIR/localization/arcmenu/v73-bindtextdomain.patch"
TOOLTIP_PATCH="$ROOT_DIR/localization/arcmenu/v73-power-tooltip-i18n.patch"
SOURCE="$ROOT_DIR/localization/arcmenu/v73-source.json"
VERIFIER="$ROOT_DIR/scripts/verify-arcmenu-localization.sh"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: ArcMenu extension not installed"
    exit 0
fi

for cmd in python3 sha256sum patch cmp install cp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$CONSTANTS_TARGET" "$MENU_WIDGETS_TARGET" "$BIND_PATCH" "$TOOLTIP_PATCH" "$SOURCE" "$VERIFIER"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required ArcMenu localization file missing: $path" >&2
        exit 1
    }
done

read -r expected_version expected_name expected_metadata_sha expected_constants_sha expected_menu_widgets_sha < <(
    python3 - "$SOURCE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)

print(
    d["version"],
    d["version_name"],
    d["metadata_sha256"],
    d["constants_sha256"],
    d["menu_widgets_sha256"],
)
PY
)

read -r actual_version actual_name < <(
    python3 - "$EXT_DIR/metadata.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)

print(d.get("version", ""), d.get("version-name", ""))
PY
)

if [[ "$actual_version" != "$expected_version" ||
      "$actual_name" != "$expected_name" ]]; then
    echo "FAIL: ArcMenu localization is pinned to v73 / 69.2; installed version is ${actual_version:-unknown} / ${actual_name:-unknown}" >&2
    exit 1
fi

actual_metadata_sha="$(sha256sum "$EXT_DIR/metadata.json" | awk '{print $1}')"
if [[ "$actual_metadata_sha" != "$expected_metadata_sha" ]]; then
    echo "FAIL: ArcMenu v73 metadata fingerprint differs from audited archive" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

ensure_pristine_backup() {
    local target="$1"
    local backup="$2"
    local expected_sha="$3"
    local label="$4"

    if [[ ! -f "$backup" ]]; then
        local current_sha
        current_sha="$(sha256sum "$target" | awk '{print $1}')"
        if [[ "$current_sha" != "$expected_sha" ]]; then
            echo "FAIL: pristine ArcMenu v73 $label backup is missing and live file is not pristine" >&2
            exit 1
        fi
        cp -a "$target" "$backup"
        echo "Backup: $backup"
    fi

    local backup_sha
    backup_sha="$(sha256sum "$backup" | awk '{print $1}')"
    if [[ "$backup_sha" != "$expected_sha" ]]; then
        echo "FAIL: ArcMenu pristine $label backup fingerprint differs from audited v73 source" >&2
        exit 1
    fi
}

ensure_pristine_backup "$CONSTANTS_TARGET" "$CONSTANTS_BACKUP" "$expected_constants_sha" "constants.js"
ensure_pristine_backup "$MENU_WIDGETS_TARGET" "$MENU_WIDGETS_BACKUP" "$expected_menu_widgets_sha" "menuWidgets.js"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$CONSTANTS_BACKUP" "$tmp/constants.js"
cp -a "$MENU_WIDGETS_BACKUP" "$tmp/menuWidgets.js"

patch -s -p1 -d "$tmp" < "$BIND_PATCH"
patch -s -p1 -d "$tmp" < "$TOOLTIP_PATCH"

install_expected() {
    local target="$1"
    local expected="$2"
    local pristine_sha="$3"
    local label="$4"

    if cmp -s "$target" "$expected"; then
        echo "PASS: ArcMenu $label already matches repository"
        return 0
    fi

    local current_sha
    current_sha="$(sha256sum "$target" | awk '{print $1}')"
    if [[ "$current_sha" != "$pristine_sha" ]]; then
        echo "FAIL: refusing to overwrite unexpected ArcMenu v73 $label" >&2
        exit 1
    fi

    install -m 0644 "$expected" "$target"
    cmp -s "$target" "$expected" || {
        echo "FAIL: installed ArcMenu $label differs from expected result" >&2
        exit 1
    }
    echo "PASS: ArcMenu $label installed"
}

install_expected "$CONSTANTS_TARGET" "$tmp/constants.js" "$expected_constants_sha" "gettext-domain binding fix"
install_expected "$MENU_WIDGETS_TARGET" "$tmp/menuWidgets.js" "$expected_menu_widgets_sha" "power-tooltip gettext fix"

bash "$VERIFIER"
echo "PASS: ArcMenu v73 / 69.2 Polish gettext integration installed"
echo "Sign out and back in before validating ArcMenu runtime tooltips."
