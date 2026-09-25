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

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: ArcMenu extension not installed"
    exit 0
fi

for cmd in python3 sha256sum patch cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$CONSTANTS_TARGET" "$MENU_WIDGETS_TARGET" "$CONSTANTS_BACKUP" "$MENU_WIDGETS_BACKUP" "$BIND_PATCH" "$TOOLTIP_PATCH" "$SOURCE"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required ArcMenu localization verification file missing: $path" >&2
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
    echo "FAIL: expected ArcMenu v73 / 69.2, found ${actual_version:-unknown} / ${actual_name:-unknown}" >&2
    exit 1
fi

if [[ "$(sha256sum "$EXT_DIR/metadata.json" | awk '{print $1}')" != "$expected_metadata_sha" ]]; then
    echo "FAIL: ArcMenu metadata fingerprint differs" >&2
    exit 1
fi

if [[ "$(sha256sum "$CONSTANTS_BACKUP" | awk '{print $1}')" != "$expected_constants_sha" ]]; then
    echo "FAIL: ArcMenu pristine constants.js fingerprint differs" >&2
    exit 1
fi

if [[ "$(sha256sum "$MENU_WIDGETS_BACKUP" | awk '{print $1}')" != "$expected_menu_widgets_sha" ]]; then
    echo "FAIL: ArcMenu pristine menuWidgets.js fingerprint differs" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$CONSTANTS_BACKUP" "$tmp/constants.js"
cp -a "$MENU_WIDGETS_BACKUP" "$tmp/menuWidgets.js"
patch -s -p1 -d "$tmp" < "$BIND_PATCH"
patch -s -p1 -d "$tmp" < "$TOOLTIP_PATCH"

if ! cmp -s "$tmp/constants.js" "$CONSTANTS_TARGET"; then
    echo "FAIL: ArcMenu v73 Polish gettext binding fix differs from repository" >&2
    exit 1
fi

if ! cmp -s "$tmp/menuWidgets.js" "$MENU_WIDGETS_TARGET"; then
    echo "FAIL: ArcMenu v73 power-tooltip gettext fix differs from repository" >&2
    exit 1
fi

grep -Fq "bindtextdomain('arcmenu', ARCMENU_LOCALE_DIR);" "$CONSTANTS_TARGET" || {
    echo "FAIL: ArcMenu gettext domain is not explicitly bound to its locale directory" >&2
    exit 1
}

grep -Fq "super(menuLayout, _(Constants.PowerOptions[powerType].name)," "$MENU_WIDGETS_TARGET" || {
    echo "FAIL: ArcMenu power-button tooltip does not pass the runtime name through gettext" >&2
    exit 1
}

for path in "$CONSTANTS_TARGET" "$MENU_WIDGETS_TARGET" "$BIND_PATCH" "$TOOLTIP_PATCH"; do
    if grep -Fq '/home/wojciech' "$path"; then
        echo "FAIL: ArcMenu localization contains a private hardcoded path: $path" >&2
        exit 1
    fi
done

echo "PASS: ArcMenu v73 / 69.2 Polish gettext binding and power-tooltip fixes match repository"
