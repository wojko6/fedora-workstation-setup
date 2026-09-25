#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
CONSTANTS="$EXT_DIR/constants.js"
MENU_WIDGETS="$EXT_DIR/menuWidgets.js"
POLISH_MO="$EXT_DIR/locale/pl/LC_MESSAGES/arcmenu.mo"
BACKUP_DIR="$EXT_DIR/.localization-backup-v74"
BACKUP_CONSTANTS="$BACKUP_DIR/constants.js"

PATCH="$ROOT_DIR/localization/arcmenu/v74-bindtextdomain.patch"
SOURCE="$ROOT_DIR/localization/arcmenu/v74-source.json"
VERIFIER="$ROOT_DIR/scripts/verify-arcmenu-v74-candidate.sh"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "FAIL: ArcMenu extension not installed" >&2
    exit 1
fi

for cmd in python3 sha256sum patch cmp install cp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$EXT_DIR/metadata.json" "$CONSTANTS" "$MENU_WIDGETS" "$POLISH_MO" "$PATCH" "$SOURCE" "$VERIFIER"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required ArcMenu v74 candidate file missing: $path" >&2
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
    echo "FAIL: ArcMenu candidate is pinned to v74 / 70.0; installed version is ${actual_version:-unknown} / ${actual_name:-unknown}" >&2
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

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$BACKUP_CONSTANTS" ]]; then
    check_sha "$CONSTANTS" "$constants_sha" "pristine constants.js"
    cp -a "$CONSTANTS" "$BACKUP_CONSTANTS"
    echo "Backup: $BACKUP_CONSTANTS"
fi

check_sha "$BACKUP_CONSTANTS" "$constants_sha" "pristine constants.js backup"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$BACKUP_CONSTANTS" "$tmp/constants.js"
patch -s -p1 -d "$tmp" < "$PATCH"

if cmp -s "$CONSTANTS" "$tmp/constants.js"; then
    echo "PASS: ArcMenu v74 gettext-domain candidate fix already installed"
else
    current_sha="$(sha256sum "$CONSTANTS" | awk '{print $1}')"
    [[ "$current_sha" == "$constants_sha" ]] || {
        echo "FAIL: refusing to overwrite unexpected ArcMenu v74 constants.js" >&2
        exit 1
    }

    install -m 0644 "$tmp/constants.js" "$CONSTANTS"
    cmp -s "$CONSTANTS" "$tmp/constants.js" || {
        echo "FAIL: installed ArcMenu v74 constants.js differs from candidate" >&2
        exit 1
    }
    echo "PASS: ArcMenu v74 gettext-domain candidate fix installed"
fi

bash "$VERIFIER"
echo "PASS: ArcMenu v74 / 70.0 candidate localization integration is internally consistent"
echo "Sign out and back in, then visually check the ArcMenu power-button tooltips."
