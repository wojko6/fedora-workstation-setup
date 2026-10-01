#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
DOMAIN="arcmenu"
EXPECTED_COMPLETION_ENTRIES="1"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"

METADATA="$EXT_DIR/metadata.json"
CONSTANTS="$EXT_DIR/constants.js"
MENU_WIDGETS="$EXT_DIR/menuWidgets.js"
APP_MENU="$EXT_DIR/appMenu.js"

POLISH_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${POLISH_MO}.upstream-v74.bak"

BACKUP_CONSTANTS="$EXT_DIR/.localization-backup-v74/constants.js"

PATCH="$ROOT_DIR/localization/arcmenu/v74-bindtextdomain.patch"
OVERLAY="$ROOT_DIR/localization/arcmenu/v74-completion.po"
SOURCE="$ROOT_DIR/localization/arcmenu/v74-source.json"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: ArcMenu extension not installed"
    exit 0
fi

for cmd in \
    python3 sha256sum patch cmp \
    msgfmt msgunfmt msgcat msgattrib
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
    "$BACKUP_MO" \
    "$BACKUP_CONSTANTS" \
    "$PATCH" \
    "$OVERLAY" \
    "$SOURCE"
do
    [[ -f "$path" ]] || {
        echo "FAIL: required ArcMenu verification file missing: $path" >&2
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

[[ "${actual_meta[0]:-}" == "$expected_version" &&
   "${actual_meta[1]:-}" == "$expected_name" ]] || {
    echo "FAIL: unexpected ArcMenu version" >&2
    exit 1
}

[[ "${actual_meta[2]:-}" == "$DOMAIN" ]] || {
    echo "FAIL: unexpected ArcMenu gettext-domain" >&2
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
check_sha "$BACKUP_CONSTANTS" "$constants_sha" "pristine constants.js backup"
check_sha "$BACKUP_MO" "$polish_mo_sha" "upstream Polish catalog backup"

grep -Fq "_('Unpin from Folder')" "$APP_MENU" || {
    echo "FAIL: ArcMenu audited Unpin from Folder source string is missing" >&2
    exit 1
}

msgfmt --check --check-format "$OVERLAY" -o /dev/null

completion_entries="$(grep -c '^msgid "' "$OVERLAY")"
completion_entries=$((completion_entries - 1))

[[ "$completion_entries" -eq "$EXPECTED_COMPLETION_ENTRIES" ]] || {
    echo "FAIL: ArcMenu completion entry count: expected $EXPECTED_COMPLETION_ENTRIES, found $completion_entries" >&2
    exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$BACKUP_CONSTANTS" "$tmp/constants.js"
patch -s -p1 -d "$tmp" < "$PATCH"

cmp -s "$tmp/constants.js" "$CONSTANTS" || {
    echo "FAIL: ArcMenu v74 gettext-domain binding differs from repository" >&2
    exit 1
}

grep -Fq "bindtextdomain('arcmenu', ARCMENU_LOCALE_DIR);" "$CONSTANTS" || {
    echo "FAIL: ArcMenu gettext domain is not explicitly bound" >&2
    exit 1
}

msgunfmt "$BACKUP_MO" -o "$tmp/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmp/upstream.po" \
    -o "$tmp/merged.po"

msgfmt --check --check-format \
    "$tmp/merged.po" \
    -o "$tmp/$DOMAIN.mo"

cmp -s "$tmp/$DOMAIN.mo" "$POLISH_MO" || {
    echo "FAIL: ArcMenu Polish catalog differs from repository completion" >&2
    exit 1
}

untranslated="$(
    msgattrib --untranslated --no-obsolete "$tmp/merged.po" \
        | grep -c '^msgid ' || true
)"

fuzzy="$(
    msgattrib --only-fuzzy --no-obsolete "$tmp/merged.po" \
        | grep -c '^msgid ' || true
)"

[[ "$untranslated" -eq 0 && "$fuzzy" -eq 0 ]] || {
    echo "FAIL: ArcMenu merged catalog incomplete: untranslated=$untranslated fuzzy=$fuzzy" >&2
    exit 1
}

python3 - \
    "$BACKUP_MO" \
    "$POLISH_MO" <<'PY'
import gettext
import sys

upstream_path, installed_path = sys.argv[1:]

source = "Unpin from Folder"
expected = "Odepnij z folderu"

with open(upstream_path, "rb") as f:
    upstream = gettext.GNUTranslations(f)

with open(installed_path, "rb") as f:
    installed = gettext.GNUTranslations(f)

upstream_value = upstream.gettext(source)

if upstream_value != source:
    raise SystemExit(
        f"FAIL: expected ArcMenu upstream gap for {source!r}, "
        f"got {upstream_value!r}"
    )

actual = installed.gettext(source)

if actual != expected:
    raise SystemExit(
        f"FAIL: ArcMenu translation mismatch: "
        f"expected {expected!r}, got {actual!r}"
    )

print("ArcMenu completion gettext checks: 1")
PY

for path in "$CONSTANTS" "$PATCH" "$OVERLAY"; do
    if grep -Fq '/home/wojciech' "$path"; then
        echo "FAIL: ArcMenu localization contains private hardcoded path: $path" >&2
        exit 1
    fi
done

echo "PASS: ArcMenu v74 / 70.0 Polish gettext binding and completion match repository"
