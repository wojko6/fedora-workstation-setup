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

for path in "$SOURCE_PO" "$TARGET_MO" "$BACKUP_MO" "$METADATA"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Tiling Shell localization file missing: $path" >&2
        exit 1
    fi
done

python3 - "$METADATA" "$EXPECTED_VERSION" "$EXPECTED_VERSION_NAME" "$DOMAIN" <<'PY'
import json
import sys

path, expected_version, expected_name, expected_domain = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

if str(data.get("version", "")) != expected_version:
    raise SystemExit("FAIL: unexpected Tiling Shell numeric version")
if str(data.get("version-name", "")) != expected_name:
    raise SystemExit("FAIL: unexpected Tiling Shell version-name")
if str(data.get("gettext-domain", "")) != expected_domain:
    raise SystemExit("FAIL: unexpected Tiling Shell gettext-domain")
PY

msgfmt --check "$SOURCE_PO" -o /dev/null

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmp_dir/upstream.po"
msgcat --use-first \
    "$SOURCE_PO" \
    "$tmp_dir/upstream.po" \
    -o "$tmp_dir/merged.po"
msgfmt --check "$tmp_dir/merged.po" -o "$tmp_dir/expected.mo"

if ! cmp -s "$tmp_dir/expected.mo" "$TARGET_MO"; then
    echo "FAIL: Tiling Shell Polish localization differs from repository completion" >&2
    exit 1
fi

untranslated="$(msgattrib --untranslated --no-obsolete "$tmp_dir/merged.po" | grep -c '^msgid ' || true)"
fuzzy="$(msgattrib --only-fuzzy --no-obsolete "$tmp_dir/merged.po" | grep -c '^msgid ' || true)"

if [[ "$untranslated" -ne 0 || "$fuzzy" -ne 0 ]]; then
    echo "FAIL: merged Tiling Shell Polish catalog is not complete (untranslated=$untranslated fuzzy=$fuzzy)" >&2
    exit 1
fi

echo "PASS: Tiling Shell 17.3 Polish localization matches repository completion (15 entries, 0 fuzzy)"
