#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
PREFS="$EXT_DIR/prefs.js"
EXTENSION="$EXT_DIR/extension.js"
UTIL="$EXT_DIR/util.js"
DOMAIN="gnome-shell-extension-user-theme"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_DIR="$EXT_DIR/.localization-backup-v79"
BACKUP_METADATA="$BACKUP_DIR/metadata.json"
BACKUP_PREFS="$BACKUP_DIR/prefs.js"
PO="$ROOT_DIR/localization/user-theme/pl.po"
PREFS_PATCH="$ROOT_DIR/patches/gnome-extensions/user-theme/prefs-gettext.patch"
METADATA_PATCH="$ROOT_DIR/patches/gnome-extensions/user-theme/metadata-pl.patch"

EXPECTED_VERSION="79"
EXPECTED_VERSION_NAME="50.4"
EXPECTED_DOMAIN="$DOMAIN"
EXPECTED_METADATA_SHA="a483cf955bac211e10f736d0bcdee8143ca98660c007f9fe432e401bb0e495f7"
EXPECTED_PREFS_SHA="71e70750848b1e2c656b9d7bd6567f332da55b0a250dfe95e9327c31870499b3"
EXPECTED_EXTENSION_SHA="da03a95b29e19a346ead6f16495d35b6647b8d73df930fee6a907e30885678f6"
EXPECTED_UTIL_SHA="93d2326bdb3e3bb71f5810f4a004b7695a0a44f80ea705356e8f604192629daa"
EXPECTED_ENTRIES="2"
EXPECTED_NAME="Motywy użytkownika"
EXPECTED_DESCRIPTION="Wczytuj motywy powłoki z katalogu użytkownika."

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: User Themes extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt patch cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$METADATA" "$PREFS" "$EXTENSION" "$UTIL" "$TARGET_MO" "$BACKUP_METADATA" "$BACKUP_PREFS" "$PO" "$PREFS_PATCH" "$METADATA_PATCH"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required User Themes localization file missing: $path" >&2
        exit 1
    }
done

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: User Themes v79 $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$EXTENSION" "$EXPECTED_EXTENSION_SHA" "extension.js"
check_sha "$UTIL" "$EXPECTED_UTIL_SHA" "util.js"
check_sha "$BACKUP_METADATA" "$EXPECTED_METADATA_SHA" "pristine metadata.json backup"
check_sha "$BACKUP_PREFS" "$EXPECTED_PREFS_SHA" "pristine prefs.js backup"

readarray -t metadata_values < <(python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
for key in ('version', 'version-name', 'gettext-domain', 'name', 'description'):
    print(data.get(key, ''))
PY
)

[[ "${metadata_values[0]:-}" == "$EXPECTED_VERSION" ]] || {
    echo "FAIL: User Themes runtime version differs" >&2
    exit 1
}
[[ "${metadata_values[1]:-}" == "$EXPECTED_VERSION_NAME" ]] || {
    echo "FAIL: User Themes runtime version-name differs" >&2
    exit 1
}
[[ "${metadata_values[2]:-}" == "$EXPECTED_DOMAIN" ]] || {
    echo "FAIL: User Themes gettext domain differs" >&2
    exit 1
}
[[ "${metadata_values[3]:-}" == "$EXPECTED_NAME" ]] || {
    echo "FAIL: User Themes localized metadata name differs" >&2
    exit 1
}
[[ "${metadata_values[4]:-}" == "$EXPECTED_DESCRIPTION" ]] || {
    echo "FAIL: User Themes localized metadata description differs" >&2
    exit 1
}

msgfmt --check "$PO" -o /dev/null
completion_entries="$(grep -c '^msgid "' "$PO")"
completion_entries=$((completion_entries - 1))
[[ "$completion_entries" -eq "$EXPECTED_ENTRIES" ]] || {
    echo "FAIL: unexpected User Themes translation entry count: $completion_entries" >&2
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cp -a "$BACKUP_METADATA" "$tmpdir/metadata.json"
cp -a "$BACKUP_PREFS" "$tmpdir/prefs.js"
patch --silent -p1 -d "$tmpdir" < "$METADATA_PATCH"
patch --silent -p1 -d "$tmpdir" < "$PREFS_PATCH"

cmp -s "$tmpdir/metadata.json" "$METADATA" || {
    echo "FAIL: installed User Themes metadata.json differs from repository localization" >&2
    exit 1
}

cmp -s "$tmpdir/prefs.js" "$PREFS" || {
    echo "FAIL: installed User Themes prefs.js differs from repository gettext patch" >&2
    exit 1
}

msgfmt --check "$PO" -o "$tmpdir/$DOMAIN.mo"
cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO" || {
    echo "FAIL: installed User Themes Polish catalog differs from repository catalog" >&2
    exit 1
}

grep -Fq "gettext('Themes')" "$PREFS" || {
    echo "FAIL: User Themes group title is not gettext-managed" >&2
    exit 1
}
grep -Fq "gettext('Default')" "$PREFS" || {
    echo "FAIL: User Themes default row is not gettext-managed" >&2
    exit 1
}

python3 - "$EXT_DIR/locale" "$DOMAIN" <<'PY'
import gettext
import sys

localedir, domain = sys.argv[1:]
tr = gettext.translation(domain, localedir=localedir, languages=['pl'])
expected = {
    'Themes': 'Motywy',
    'Default': 'Domyślny',
}
for msgid, wanted in expected.items():
    actual = tr.gettext(msgid)
    if actual != wanted:
        raise SystemExit(
            f"FAIL: gettext {msgid!r}: expected {wanted!r}, found {actual!r}"
        )
print('PASS: User Themes v79 gettext catalog resolves both reviewed prefs strings')
PY

printf 'Translation entries: %d\n' "$completion_entries"
echo "PASS: User Themes v79 Polish localization matches repository"
