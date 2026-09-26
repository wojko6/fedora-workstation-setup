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
BACKUP_PREFS="$EXT_DIR/.localization-backup-v79/prefs.js"
PO="$ROOT_DIR/localization/user-theme/pl.po"
PATCH="$ROOT_DIR/patches/gnome-extensions/user-theme/prefs-gettext.patch"

EXPECTED_VERSION="79"
EXPECTED_VERSION_NAME="50.4"
EXPECTED_METADATA_SHA="a483cf955bac211e10f736d0bcdee8143ca98660c007f9fe432e401bb0e495f7"
EXPECTED_PREFS_SHA="71e70750848b1e2c656b9d7bd6567f332da55b0a250dfe95e9327c31870499b3"
EXPECTED_EXTENSION_SHA="da03a95b29e19a346ead6f16495d35b6647b8d73df930fee6a907e30885678f6"
EXPECTED_UTIL_SHA="93d2326bdb3e3bb71f5810f4a004b7695a0a44f80ea705356e8f604192629daa"
EXPECTED_ENTRIES="4"

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

for path in "$METADATA" "$PREFS" "$EXTENSION" "$UTIL" "$TARGET_MO" "$BACKUP_PREFS" "$PO" "$PATCH"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required User Themes localization file missing: $path" >&2
        exit 1
    }
done

readarray -t metadata_values < <(python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('version', ''))
print(data.get('version-name', ''))
print(data.get('gettext-domain', ''))
PY
)

version="${metadata_values[0]:-}"
version_name="${metadata_values[1]:-}"
domain="${metadata_values[2]:-}"

[[ "$version" == "$EXPECTED_VERSION" ]] || {
    echo "FAIL: User Themes version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
}
[[ "$version_name" == "$EXPECTED_VERSION_NAME" ]] || {
    echo "FAIL: User Themes version-name drift: expected $EXPECTED_VERSION_NAME, found ${version_name:-unknown}" >&2
    exit 1
}
[[ "$domain" == "$DOMAIN" ]] || {
    echo "FAIL: User Themes gettext domain drift: expected $DOMAIN, found ${domain:-unknown}" >&2
    exit 1
}

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

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$EXTENSION" "$EXPECTED_EXTENSION_SHA" "extension.js"
check_sha "$UTIL" "$EXPECTED_UTIL_SHA" "util.js"
check_sha "$BACKUP_PREFS" "$EXPECTED_PREFS_SHA" "pristine prefs.js backup"

msgfmt --check "$PO" -o /dev/null
completion_entries="$(grep -c '^msgid "' "$PO")"
completion_entries=$((completion_entries - 1))
[[ "$completion_entries" -eq "$EXPECTED_ENTRIES" ]] || {
    echo "FAIL: unexpected User Themes translation entry count: $completion_entries" >&2
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cp -a "$BACKUP_PREFS" "$tmpdir/prefs.js"
patch --silent -p1 -d "$tmpdir" < "$PATCH"

if ! cmp -s "$tmpdir/prefs.js" "$PREFS"; then
    echo "FAIL: installed User Themes prefs.js differs from repository gettext patch" >&2
    exit 1
fi

msgfmt --check "$PO" -o "$tmpdir/$DOMAIN.mo"
if ! cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO"; then
    echo "FAIL: installed User Themes Polish catalog differs from repository catalog" >&2
    exit 1
fi

grep -Fq "gettext('Themes')" "$PREFS" || {
    echo "FAIL: User Themes title is not gettext-managed" >&2
    exit 1
}
grep -Fq "gettext('Default')" "$PREFS" || {
    echo "FAIL: User Themes default row is not gettext-managed" >&2
    exit 1
}

printf 'Translation entries: %d\n' "$completion_entries"
echo "PASS: User Themes v79 Polish localization matches repository"
