#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
CONSTANTS="$EXT_DIR/constants.js"
MENU_WIDGETS="$EXT_DIR/menuWidgets.js"
POLISH_MO="$EXT_DIR/locale/pl/LC_MESSAGES/arcmenu.mo"
BACKUP="$EXT_DIR/.localization-backup-v74/constants.js"

PATCH="$ROOT_DIR/localization/arcmenu/v74-bindtextdomain.patch"
SOURCE="$ROOT_DIR/localization/arcmenu/v74-source.json"

for cmd in python3 sha256sum patch cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$EXT_DIR/metadata.json" "$CONSTANTS" "$MENU_WIDGETS" "$POLISH_MO" "$BACKUP" "$PATCH" "$SOURCE"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required ArcMenu v74 candidate verification file missing: $path" >&2
        exit 1
    }
done

read -r expected_version expected_name metadata_sha constants_sha menu_widgets_sha polish_mo_sha < <(
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
    d["polish_mo_sha256"],
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

[[ "$actual_version" == "$expected_version" && "$actual_name" == "$expected_name" ]] || {
    echo "FAIL: expected ArcMenu v74 / 70.0, found ${actual_version:-unknown} / ${actual_name:-unknown}" >&2
    exit 1
}

check_sha() {
    local path="$1" expected="$2" label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || {
        echo "FAIL: ArcMenu v74 $label fingerprint differs: $actual" >&2
        exit 1
    }
}

check_sha "$EXT_DIR/metadata.json" "$metadata_sha" "metadata.json"
check_sha "$MENU_WIDGETS" "$menu_widgets_sha" "menuWidgets.js"
check_sha "$POLISH_MO" "$polish_mo_sha" "Polish catalog"
check_sha "$BACKUP" "$constants_sha" "pristine constants.js backup"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a "$BACKUP" "$tmp/constants.js"
patch -s -p1 -d "$tmp" < "$PATCH"

cmp -s "$tmp/constants.js" "$CONSTANTS" || {
    echo "FAIL: ArcMenu v74 candidate gettext-domain fix differs from repository" >&2
    exit 1
}

grep -Fq "bindtextdomain('arcmenu', ARCMENU_LOCALE_DIR);" "$CONSTANTS" || {
    echo "FAIL: ArcMenu v74 gettext domain is not explicitly bound to its locale directory" >&2
    exit 1
}

for path in "$CONSTANTS" "$PATCH"; do
    if grep -Fq '/home/wojciech' "$path"; then
        echo "FAIL: ArcMenu v74 candidate contains a private hardcoded path: $path" >&2
        exit 1
    fi
done

echo "PASS: ArcMenu v74 / 70.0 candidate gettext-domain fix matches repository"
