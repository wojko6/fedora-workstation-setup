#!/usr/bin/env bash
set -euo pipefail

UUID="ding@rastersoft.com"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PO="$REPO_ROOT/patches/gnome-extensions/ding/pl.po"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
LOCALE_DIR="$EXT_DIR/locale/pl/LC_MESSAGES"
TARGET_MO="$LOCALE_DIR/ding.mo"

echo "=== DING POLISH TRANSLATION ==="

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: DING is not installed as a user extension"
    exit 0
fi

if [[ ! -f "$SOURCE_PO" ]]; then
    echo "FAIL: missing $SOURCE_PO"
    exit 1
fi

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "FAIL: msgfmt not found (install gettext)"
    exit 1
fi

echo "DING path: $EXT_DIR"

VERSION="$(
    python3 - "$EXT_DIR/metadata.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f).get("version", "unknown"))
PY
)"
echo "DING version: $VERSION"

echo "Validating pl.po..."
msgfmt --check "$SOURCE_PO" -o /dev/null

mkdir -p "$LOCALE_DIR"

TMP_MO="$(mktemp)"
trap 'rm -f "$TMP_MO"' EXIT

msgfmt "$SOURCE_PO" -o "$TMP_MO"

if [[ -f "$TARGET_MO" ]] && cmp -s "$TMP_MO" "$TARGET_MO"; then
    echo "PASS: custom Polish translation already installed"
    exit 0
fi

if [[ -f "$TARGET_MO" ]]; then
    BACKUP="${TARGET_MO}.upstream.bak"
    if [[ ! -f "$BACKUP" ]]; then
        cp -a "$TARGET_MO" "$BACKUP"
        echo "Backup: $BACKUP"
    fi
fi

install -m 0644 "$TMP_MO" "$TARGET_MO"

if cmp -s "$TMP_MO" "$TARGET_MO"; then
    echo "PASS: custom Polish DING translation installed"
else
    echo "FAIL: installed ding.mo verification failed"
    exit 1
fi

echo "SHA256:"
sha256sum "$TARGET_MO"
