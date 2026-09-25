#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET="$EXT_DIR/constants.js"
BACKUP_DIR="$EXT_DIR/.localization-backup-v73"
BACKUP="$BACKUP_DIR/constants.js"

PATCH="$ROOT_DIR/localization/arcmenu/v73-bindtextdomain.patch"
SOURCE="$ROOT_DIR/localization/arcmenu/v73-source.json"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: ArcMenu extension not installed"
    exit 0
fi

for cmd in python3 sha256sum patch; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

[[ -f "$TARGET" ]] || {
    echo "FAIL: ArcMenu constants.js missing" >&2
    exit 1
}

[[ -f "$PATCH" ]] || {
    echo "FAIL: ArcMenu v73 patch missing" >&2
    exit 1
}

[[ -f "$SOURCE" ]] || {
    echo "FAIL: ArcMenu v73 source fingerprints missing" >&2
    exit 1
}

read -r expected_version expected_name expected_metadata_sha expected_constants_sha < <(
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

if [[ ! -f "$BACKUP" ]]; then
    current_sha="$(sha256sum "$TARGET" | awk '{print $1}')"

    if [[ "$current_sha" != "$expected_constants_sha" ]]; then
        echo "FAIL: pristine ArcMenu v73 backup is missing and live constants.js is not pristine" >&2
        exit 1
    fi

    mkdir -p "$BACKUP_DIR"
    cp -a "$TARGET" "$BACKUP"
    echo "Backup: $BACKUP"
fi

backup_sha="$(sha256sum "$BACKUP" | awk '{print $1}')"

if [[ "$backup_sha" != "$expected_constants_sha" ]]; then
    echo "FAIL: ArcMenu pristine backup fingerprint differs from audited v73 source" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$BACKUP" "$tmp/constants.js"
patch -s -p1 -d "$tmp" < "$PATCH"

if cmp -s "$TARGET" "$tmp/constants.js"; then
    echo "PASS: ArcMenu v73 Polish gettext binding fix already installed"
    exit 0
fi

current_sha="$(sha256sum "$TARGET" | awk '{print $1}')"

if [[ "$current_sha" != "$expected_constants_sha" ]]; then
    echo "FAIL: refusing to overwrite unexpected ArcMenu v73 constants.js" >&2
    exit 1
fi

install -m 0644 "$tmp/constants.js" "$TARGET"

if ! cmp -s "$TARGET" "$tmp/constants.js"; then
    echo "FAIL: installed ArcMenu gettext fix differs from expected result" >&2
    exit 1
fi

echo "PASS: ArcMenu v73 / 69.2 Polish gettext binding fix installed"
echo "Sign out and back in before validating ArcMenu runtime tooltips."
