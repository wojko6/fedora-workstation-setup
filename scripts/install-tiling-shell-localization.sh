#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="tilingshell@ferrarodomenico.com"
DOMAIN="tilingshell"
EXPECTED_VERSION="76"
EXPECTED_VERSION_NAME="17.3"
SOURCE_PO="$ROOT_DIR/localization/tiling-shell/pl.po"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream.bak"
METADATA="$EXT_DIR/metadata.json"

for cmd in msgfmt msgunfmt msgcat python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: $cmd not found" >&2
        exit 1
    fi
done

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Tiling Shell extension not installed: $UUID"
    exit 0
fi

if [[ ! -f "$SOURCE_PO" ]]; then
    echo "FAIL: missing Tiling Shell Polish overlay: $SOURCE_PO" >&2
    exit 1
fi

if [[ ! -f "$TARGET_MO" ]]; then
    echo "FAIL: upstream Tiling Shell Polish catalog not found: $TARGET_MO" >&2
    exit 1
fi

if [[ ! -f "$METADATA" ]]; then
    echo "FAIL: Tiling Shell metadata missing: $METADATA" >&2
    exit 1
fi

python3 - "$METADATA" "$EXPECTED_VERSION" "$EXPECTED_VERSION_NAME" "$DOMAIN" <<'PY'
import json
import sys

path, expected_version, expected_name, expected_domain = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

actual_version = str(data.get("version", ""))
actual_name = str(data.get("version-name", ""))
actual_domain = str(data.get("gettext-domain", ""))

if actual_version != expected_version or actual_name != expected_name:
    raise SystemExit(
        "FAIL: Tiling Shell version changed; re-audit localization before applying "
        f"(expected {expected_name}/{expected_version}, got {actual_name or '?'}/{actual_version or '?'})"
    )

if actual_domain != expected_domain:
    raise SystemExit(
        f"FAIL: unexpected Tiling Shell gettext-domain: {actual_domain!r}"
    )
PY

msgfmt --check "$SOURCE_PO" -o /dev/null

if [[ ! -f "$BACKUP_MO" ]]; then
    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmp_dir/upstream.po"

# Keep the complete upstream Polish catalog and overlay only the 15 entries
# that are untranslated in the tested Tiling Shell 17.3 / EGO version 76.
msgcat --use-first \
    "$SOURCE_PO" \
    "$tmp_dir/upstream.po" \
    -o "$tmp_dir/merged.po"

msgfmt --check "$tmp_dir/merged.po" -o "$tmp_dir/merged.mo"

if cmp -s "$tmp_dir/merged.mo" "$TARGET_MO"; then
    echo "PASS: Tiling Shell Polish completion already installed"
    exit 0
fi

install -m 0644 "$tmp_dir/merged.mo" "$TARGET_MO"

if cmp -s "$tmp_dir/merged.mo" "$TARGET_MO"; then
    echo "PASS: Tiling Shell Polish completion installed"
else
    echo "FAIL: Tiling Shell localization install verification failed" >&2
    exit 1
fi
