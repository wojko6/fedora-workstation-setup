#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="tilingshell@ferrarodomenico.com"
DOMAIN="tilingshell"
EXPECTED_VERSION="76"
EXPECTED_VERSION_NAME="17.3"

EXPECTED_METADATA_SHA="29c000e1967d1f7cbf3517474e9db172ae769de22e5d858f173cd7c36ce98d00"
EXPECTED_EDITOR_SHA="9cac1511fa8501089e0416ff7129da59178546326545a81a403cb7c434397d48"

SOURCE_PO="$ROOT_DIR/localization/tiling-shell/pl.po"
PATCH="$ROOT_DIR/patches/gnome-extensions/tiling-shell/v76-editor-legend-gettext.patch"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"

EDITOR="$EXT_DIR/components/editor/editorDialog.js"
EDITOR_BACKUP="${EDITOR}.upstream-v76.bak"

TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream.bak"

VERIFIER="$ROOT_DIR/scripts/verify-tiling-shell-localization.sh"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Tiling Shell extension not installed: $UUID"
    exit 0
fi

for cmd in \
    msgfmt msgunfmt msgcat python3 sha256sum patch cmp install cp
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command unavailable: $cmd" >&2
        exit 1
    }
done

for path in \
    "$SOURCE_PO" "$PATCH" "$TARGET_MO" "$METADATA" "$EDITOR" "$VERIFIER"
do
    [[ -f "$path" ]] || {
        echo "FAIL: required Tiling Shell file missing: $path" >&2
        exit 1
    }
done

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual

    actual="$(sha256sum "$path" | awk '{print $1}')"

    [[ "$actual" == "$expected" ]] || {
        echo "FAIL: Tiling Shell v76 $label fingerprint differs: $actual" >&2
        exit 1
    }
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"

python3 - "$METADATA" "$EXPECTED_VERSION" "$EXPECTED_VERSION_NAME" "$DOMAIN" <<'PY'
import json
import sys

path, version, version_name, domain = sys.argv[1:]

with open(path, encoding="utf-8") as f:
    data = json.load(f)

if str(data.get("version", "")) != version:
    raise SystemExit("FAIL: unexpected Tiling Shell numeric version")

if str(data.get("version-name", "")) != version_name:
    raise SystemExit("FAIL: unexpected Tiling Shell version-name")

if str(data.get("gettext-domain", "")) != domain:
    raise SystemExit("FAIL: unexpected Tiling Shell gettext-domain")
PY

msgfmt --check --check-format "$SOURCE_PO" -o /dev/null

if [[ ! -f "$EDITOR_BACKUP" ]]; then
    current_sha="$(sha256sum "$EDITOR" | awk '{print $1}')"

    if [[ "$current_sha" == "$EXPECTED_EDITOR_SHA" ]]; then
        cp -a "$EDITOR" "$EDITOR_BACKUP"
        echo "Backup: $EDITOR_BACKUP"
    else
        found=""

        shopt -s nullglob
        for candidate in "${EDITOR}.backup-"*; do
            candidate_sha="$(sha256sum "$candidate" | awk '{print $1}')"

            if [[ "$candidate_sha" == "$EXPECTED_EDITOR_SHA" ]]; then
                [[ -z "$found" ]] || {
                    echo "FAIL: multiple pristine editorDialog.js backups found" >&2
                    exit 1
                }

                found="$candidate"
            fi
        done
        shopt -u nullglob

        [[ -n "$found" ]] || {
            echo "FAIL: no audited pristine editorDialog.js backup found" >&2
            exit 1
        }

        cp -a "$found" "$EDITOR_BACKUP"

        echo "Recovered pristine editor from: $found"
        echo "Backup: $EDITOR_BACKUP"
    fi
fi

check_sha \
    "$EDITOR_BACKUP" \
    "$EXPECTED_EDITOR_SHA" \
    "pristine editorDialog.js backup"

if [[ ! -f "$BACKUP_MO" ]]; then
    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/components/editor"

cp -a \
    "$EDITOR_BACKUP" \
    "$tmp/components/editor/editorDialog.js"

patch --batch --forward \
    -p1 \
    -d "$tmp" \
    < "$PATCH" >/dev/null

msgunfmt "$BACKUP_MO" -o "$tmp/upstream.po"

msgcat --use-first \
    "$SOURCE_PO" \
    "$tmp/upstream.po" \
    -o "$tmp/merged.po"

msgfmt --check --check-format \
    "$tmp/merged.po" \
    -o "$tmp/$DOMAIN.mo"

install -m 0644 \
    "$tmp/components/editor/editorDialog.js" \
    "$EDITOR"

install -m 0644 \
    "$tmp/$DOMAIN.mo" \
    "$TARGET_MO"

bash "$VERIFIER"

echo "PASS: Tiling Shell v76 / 17.3 Polish localization installed"
