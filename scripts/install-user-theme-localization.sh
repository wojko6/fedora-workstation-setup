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
VERIFIER="$ROOT_DIR/scripts/verify-user-theme-localization.sh"

EXPECTED_VERSION="79"
EXPECTED_VERSION_NAME="50.4"
EXPECTED_METADATA_SHA="a483cf955bac211e10f736d0bcdee8143ca98660c007f9fe432e401bb0e495f7"
EXPECTED_PREFS_SHA="71e70750848b1e2c656b9d7bd6567f332da55b0a250dfe95e9327c31870499b3"
EXPECTED_EXTENSION_SHA="da03a95b29e19a346ead6f16495d35b6647b8d73df930fee6a907e30885678f6"
EXPECTED_UTIL_SHA="93d2326bdb3e3bb71f5810f4a004b7695a0a44f80ea705356e8f604192629daa"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: User Themes extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt patch cmp install cp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$METADATA" "$PREFS" "$EXTENSION" "$UTIL" "$PO" "$PREFS_PATCH" "$METADATA_PATCH" "$VERIFIER"; do
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

check_sha "$EXTENSION" "$EXPECTED_EXTENSION_SHA" "extension.js"
check_sha "$UTIL" "$EXPECTED_UTIL_SHA" "util.js"
msgfmt --check "$PO" -o /dev/null

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$BACKUP_METADATA" ]]; then
    check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "pristine metadata.json"
    cp -a "$METADATA" "$BACKUP_METADATA"
    echo "Backup: $BACKUP_METADATA"
else
    check_sha "$BACKUP_METADATA" "$EXPECTED_METADATA_SHA" "pristine metadata.json backup"
fi

if [[ ! -f "$BACKUP_PREFS" ]]; then
    check_sha "$PREFS" "$EXPECTED_PREFS_SHA" "pristine prefs.js"
    cp -a "$PREFS" "$BACKUP_PREFS"
    echo "Backup: $BACKUP_PREFS"
else
    check_sha "$BACKUP_PREFS" "$EXPECTED_PREFS_SHA" "pristine prefs.js backup"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cp -a "$BACKUP_METADATA" "$tmpdir/metadata.json"
cp -a "$BACKUP_PREFS" "$tmpdir/prefs.js"

patch --silent -p1 -d "$tmpdir" < "$METADATA_PATCH"
patch --silent -p1 -d "$tmpdir" < "$PREFS_PATCH"
msgfmt --check "$PO" -o "$tmpdir/$DOMAIN.mo"

if ! cmp -s "$METADATA" "$BACKUP_METADATA" &&
   ! cmp -s "$METADATA" "$tmpdir/metadata.json"; then
    echo "FAIL: live User Themes metadata.json is neither pristine v79 nor the repository-managed localized form" >&2
    exit 1
fi

if ! cmp -s "$PREFS" "$BACKUP_PREFS" &&
   ! cmp -s "$PREFS" "$tmpdir/prefs.js"; then
    echo "FAIL: live User Themes prefs.js is neither pristine v79 nor the repository-managed gettext form" >&2
    exit 1
fi

mkdir -p "$(dirname -- "$TARGET_MO")"
install -m 0644 "$tmpdir/metadata.json" "$METADATA"
install -m 0644 "$tmpdir/prefs.js" "$PREFS"
install -m 0644 "$tmpdir/$DOMAIN.mo" "$TARGET_MO"

bash "$VERIFIER"
echo "PASS: User Themes v79 Polish localization installed"
echo "Close and reopen the User Themes preferences window to validate the localized title and rows."
