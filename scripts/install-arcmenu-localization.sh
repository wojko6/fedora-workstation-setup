#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
DOMAIN="arcmenu"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"

METADATA="$EXT_DIR/metadata.json"
CONSTANTS="$EXT_DIR/constants.js"
MENU_WIDGETS="$EXT_DIR/menuWidgets.js"
APP_MENU="$EXT_DIR/appMenu.js"

POLISH_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${POLISH_MO}.upstream-v74.bak"

BACKUP_DIR="$EXT_DIR/.localization-backup-v74"
BACKUP_CONSTANTS="$BACKUP_DIR/constants.js"

PATCH="$ROOT_DIR/localization/arcmenu/v74-bindtextdomain.patch"
OVERLAY="$ROOT_DIR/localization/arcmenu/v74-completion.po"
SOURCE="$ROOT_DIR/localization/arcmenu/v74-source.json"
VERIFIER="$ROOT_DIR/scripts/verify-arcmenu-localization.sh"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: ArcMenu extension not installed"
    exit 0
fi

for cmd in \
    python3 sha256sum patch cmp install cp \
    msgfmt msgunfmt msgcat
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in \
    "$METADATA" \
    "$CONSTANTS" \
    "$MENU_WIDGETS" \
    "$APP_MENU" \
    "$POLISH_MO" \
    "$PATCH" \
    "$OVERLAY" \
    "$SOURCE" \
    "$VERIFIER"
do
    [[ -f "$path" ]] || {
        echo "FAIL: required ArcMenu localization file missing: $path" >&2
        exit 1
    }
done

readarray -t manifest < <(
    python3 - "$SOURCE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)

for key in (
    "version",
    "version_name",
    "metadata_sha256",
    "constants_sha256",
    "menu_widgets_sha256",
    "app_menu_sha256",
    "polish_mo_sha256",
):
    print(d[key])
PY
)

expected_version="${manifest[0]}"
expected_name="${manifest[1]}"
metadata_sha="${manifest[2]}"
constants_sha="${manifest[3]}"
menu_widgets_sha="${manifest[4]}"
app_menu_sha="${manifest[5]}"
polish_mo_sha="${manifest[6]}"

readarray -t actual_meta < <(
    python3 - "$METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)

print(d.get("version", ""))
print(d.get("version-name", ""))
print(d.get("gettext-domain", ""))
PY
)

actual_version="${actual_meta[0]:-}"
actual_name="${actual_meta[1]:-}"
actual_domain="${actual_meta[2]:-}"

[[ "$actual_version" == "$expected_version" &&
   "$actual_name" == "$expected_name" ]] || {
    echo "FAIL: ArcMenu localization is pinned to v74 / 70.0; installed version is ${actual_version:-unknown} / ${actual_name:-unknown}" >&2
    exit 1
}

[[ "$actual_domain" == "$DOMAIN" ]] || {
    echo "FAIL: unexpected ArcMenu gettext-domain: ${actual_domain:-missing}" >&2
    exit 1
}

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual

    actual="$(sha256sum "$path" | awk '{print $1}')"

    [[ "$actual" == "$expected" ]] || {
        echo "FAIL: ArcMenu v74 $label fingerprint differs: $actual" >&2
        exit 1
    }
}

check_sha "$METADATA" "$metadata_sha" "metadata.json"
check_sha "$MENU_WIDGETS" "$menu_widgets_sha" "menuWidgets.js"
check_sha "$APP_MENU" "$app_menu_sha" "appMenu.js"

grep -Fq "_('Unpin from Folder')" "$APP_MENU" || {
    echo "FAIL: ArcMenu v74 audited source string is missing" >&2
    exit 1
}

msgfmt --check --check-format "$OVERLAY" -o /dev/null

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$BACKUP_CONSTANTS" ]]; then
    check_sha "$CONSTANTS" "$constants_sha" "pristine constants.js"
    cp -a "$CONSTANTS" "$BACKUP_CONSTANTS"
    echo "Backup: $BACKUP_CONSTANTS"
fi

check_sha \
    "$BACKUP_CONSTANTS" \
    "$constants_sha" \
    "pristine constants.js backup"

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$POLISH_MO" | awk '{print $1}')"

    if [[ "$current_sha" == "$polish_mo_sha" ]]; then
        cp -a "$POLISH_MO" "$BACKUP_MO"
        echo "Backup: $BACKUP_MO"
    else
        found_backup=""

        shopt -s nullglob
        for candidate in "${POLISH_MO}.backup-"*; do
            candidate_sha="$(sha256sum "$candidate" | awk '{print $1}')"

            if [[ "$candidate_sha" == "$polish_mo_sha" ]]; then
                if [[ -n "$found_backup" ]]; then
                    echo "FAIL: multiple pristine ArcMenu catalog backups found" >&2
                    exit 1
                fi

                found_backup="$candidate"
            fi
        done
        shopt -u nullglob

        if [[ -z "$found_backup" ]]; then
            echo "FAIL: ArcMenu live Polish catalog is not pristine and no audited pristine backup was found" >&2
            echo "Current SHA: $current_sha" >&2
            exit 1
        fi

        cp -a "$found_backup" "$BACKUP_MO"
        echo "Recovered pristine catalog from: $found_backup"
        echo "Backup: $BACKUP_MO"
    fi
fi

check_sha \
    "$BACKUP_MO" \
    "$polish_mo_sha" \
    "upstream Polish catalog backup"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$BACKUP_CONSTANTS" "$tmp/constants.js"

patch -s -p1 -d "$tmp" < "$PATCH"

msgunfmt "$BACKUP_MO" -o "$tmp/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmp/upstream.po" \
    -o "$tmp/merged.po"

msgfmt --check --check-format \
    "$tmp/merged.po" \
    -o "$tmp/$DOMAIN.mo"

if cmp -s "$CONSTANTS" "$tmp/constants.js"; then
    echo "PASS: ArcMenu v74 gettext-domain binding fix already installed"
else
    current_constants_sha="$(sha256sum "$CONSTANTS" | awk '{print $1}')"

    [[ "$current_constants_sha" == "$constants_sha" ]] || {
        echo "FAIL: refusing to overwrite unexpected ArcMenu v74 constants.js" >&2
        exit 1
    }

    install -m 0644 "$tmp/constants.js" "$CONSTANTS"

    cmp -s "$CONSTANTS" "$tmp/constants.js" || {
        echo "FAIL: installed ArcMenu constants.js differs from candidate" >&2
        exit 1
    }

    echo "PASS: ArcMenu v74 gettext-domain binding fix installed"
fi

if cmp -s "$POLISH_MO" "$tmp/$DOMAIN.mo"; then
    echo "PASS: ArcMenu v74 Polish completion already installed"
else
    install -m 0644 "$tmp/$DOMAIN.mo" "$POLISH_MO"

    cmp -s "$POLISH_MO" "$tmp/$DOMAIN.mo" || {
        echo "FAIL: installed ArcMenu Polish catalog differs from candidate" >&2
        exit 1
    }

    echo "PASS: ArcMenu v74 Polish completion installed"
fi

bash "$VERIFIER"

echo "PASS: ArcMenu v74 / 70.0 Polish gettext binding and completion installed"
echo "Sign out and back in before validating ArcMenu runtime tooltips."
