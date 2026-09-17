#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="advanced-media-controller@sanjai.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
EXTENSION_JS="$EXT_DIR/extension.js"
PREFS_JS="$EXT_DIR/prefs.js"
PO="$ROOT_DIR/localization/advanced-media-controller/pl.po"
POT="$ROOT_DIR/localization/advanced-media-controller/v31.pot"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/advanced-media-controller.mo"
BACKUP_MO="${TARGET_MO}.pre-repo-v31.bak"
VERIFIER="$ROOT_DIR/scripts/verify-advanced-media-controller-localization.sh"

EXPECTED_VERSION="31"
EXPECTED_VERSION_NAME="6.5"
EXPECTED_DOMAIN="advanced-media-controller"
EXPECTED_ENTRIES="276"
EXPECTED_METADATA_SHA="ed5afc509700e3f0d7a158ccc1969407b44f7cbeb8ef46366eeeec2eccaa196c"
EXPECTED_EXTENSION_SHA="2582e6c0cd90f44f7dfb9eb8313c9dfca0d718a55f59aedf0307857d3e80a275"
EXPECTED_PREFS_SHA="225c05e48f57cfd9f1c8cf5573600b588179de799bbe5d359c5fb6ecfddd9d0d"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Advanced Media Controller extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt msgcmp gettext install cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$METADATA" "$EXTENSION_JS" "$PREFS_JS" "$PO" "$POT" "$VERIFIER"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required Advanced Media Controller localization file missing: $path" >&2
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
    echo "FAIL: Advanced Media Controller version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
}
[[ "$version_name" == "$EXPECTED_VERSION_NAME" ]] || {
    echo "FAIL: Advanced Media Controller version-name drift: expected $EXPECTED_VERSION_NAME, found ${version_name:-unknown}" >&2
    exit 1
}
[[ "$domain" == "$EXPECTED_DOMAIN" ]] || {
    echo "FAIL: Advanced Media Controller gettext domain drift: expected $EXPECTED_DOMAIN, found ${domain:-unknown}" >&2
    exit 1
}

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Advanced Media Controller v31 $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$EXTENSION_JS" "$EXPECTED_EXTENSION_SHA" "extension.js"
check_sha "$PREFS_JS" "$EXPECTED_PREFS_SHA" "prefs.js"

msgfmt --check "$PO" -o /dev/null
msgcmp --use-fuzzy "$PO" "$POT" >/dev/null

entries="$(grep -c '^msgid "' "$PO")"
entries=$((entries - 1))
[[ "$entries" -eq "$EXPECTED_ENTRIES" ]] || {
    echo "FAIL: Advanced Media Controller Polish catalog entry count: expected $EXPECTED_ENTRIES, found $entries" >&2
    exit 1
}

stats="$(LC_ALL=C msgfmt --statistics "$PO" -o /dev/null 2>&1 || true)"
if grep -Eq '(^|, )[1-9][0-9]* fuzzy translation' <<<"$stats" ||
   grep -Eq '(^|, )[1-9][0-9]* untranslated message' <<<"$stats"; then
    echo "FAIL: Advanced Media Controller Polish catalog is incomplete: $stats" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
msgfmt --check "$PO" -o "$tmpdir/advanced-media-controller.mo"

mkdir -p "$(dirname -- "$TARGET_MO")"
if [[ -f "$TARGET_MO" ]] && ! cmp -s "$tmpdir/advanced-media-controller.mo" "$TARGET_MO"; then
    if [[ ! -f "$BACKUP_MO" ]]; then
        cp -a "$TARGET_MO" "$BACKUP_MO"
        echo "Backup: $BACKUP_MO"
    fi
fi

install -m 0644 "$tmpdir/advanced-media-controller.mo" "$TARGET_MO"

bash "$VERIFIER"
echo "PASS: Advanced Media Controller v31 / 6.5 Polish localization installed"
echo "Sign out and back in to reload Advanced Media Controller translations."
