#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="arcmenu@arcmenu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET="$EXT_DIR/constants.js"
BACKUP="$EXT_DIR/.localization-backup-v73/constants.js"

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
    echo "FAIL: ArcMenu source fingerprints missing" >&2
    exit 1
}

[[ -f "$BACKUP" ]] || {
    echo "FAIL: ArcMenu pristine v73 backup missing" >&2
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
    echo "FAIL: expected ArcMenu v73 / 69.2, found ${actual_version:-unknown} / ${actual_name:-unknown}" >&2
    exit 1
fi

if [[ "$(sha256sum "$EXT_DIR/metadata.json" | awk '{print $1}')" != "$expected_metadata_sha" ]]; then
    echo "FAIL: ArcMenu metadata fingerprint differs" >&2
    exit 1
fi

if [[ "$(sha256sum "$BACKUP" | awk '{print $1}')" != "$expected_constants_sha" ]]; then
    echo "FAIL: ArcMenu pristine constants.js fingerprint differs" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -a "$BACKUP" "$tmp/constants.js"
patch -s -p1 -d "$tmp" < "$PATCH"

if ! cmp -s "$tmp/constants.js" "$TARGET"; then
    echo "FAIL: ArcMenu v73 Polish gettext binding fix differs from repository" >&2
    exit 1
fi

if ! grep -Fq "bindtextdomain('arcmenu', ARCMENU_LOCALE_DIR);" "$TARGET"; then
    echo "FAIL: ArcMenu gettext domain is not explicitly bound to its locale directory" >&2
    exit 1
fi

if grep -Fq '/home/wojciech' "$TARGET" ||
   grep -Fq '/home/wojciech' "$PATCH"; then
    echo "FAIL: ArcMenu localization contains a private hardcoded path" >&2
    exit 1
fi

echo "PASS: ArcMenu v73 / 69.2 Polish gettext binding fix matches repository"
