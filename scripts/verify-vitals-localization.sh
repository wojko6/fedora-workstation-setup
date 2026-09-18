#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="Vitals@CoreCoding.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
SENSORS="$EXT_DIR/sensors.js"
PREFS_JS="$EXT_DIR/prefs.js"
PREFS_UI="$EXT_DIR/prefs.ui"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/vitals.mo"
BACKUP_MO="${TARGET_MO}.upstream-v85.bak"
OVERLAY="$ROOT_DIR/localization/vitals/v85-completion.po"

EXPECTED_VERSION="85"
EXPECTED_DOMAIN="vitals"
EXPECTED_METADATA_SHA="44a7e4b91c747b8ff3c1dfd8fb28e0dcf1564a36c7bd8cdb60bebc4826de8604"
EXPECTED_SENSORS_SHA="44a12381e932005c3a7272a14c9e5b3d6f7b320aba022ce7a1b29f67dd1e878c"
EXPECTED_PREFS_JS_SHA="b7e0a29d7f36d65fbb50f53d15fa2f3dfd00eb600a257d59581f0ff592a94149"
EXPECTED_PREFS_UI_SHA="3691d198899a1269820f7c074730b3c7a2158ddc359a4c9131bacb4b0d8182f4"
EXPECTED_UPSTREAM_MO_SHA="107547ee28ae386bf1b609f55861a1977a23f100d5931f0c49e996869c17e2d2"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Vitals extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt msgcat msgunfmt cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

for path in "$METADATA" "$SENSORS" "$PREFS_JS" "$PREFS_UI" "$OVERLAY" "$TARGET_MO"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Vitals localization file missing: $path" >&2
        exit 1
    fi
done

readarray -t metadata_values < <(python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('version', ''))
print(data.get('gettext-domain', ''))
PY
)

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Vitals version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
fi

if [[ "$domain" != "$EXPECTED_DOMAIN" ]]; then
    echo "FAIL: Vitals gettext domain drift: expected $EXPECTED_DOMAIN, found ${domain:-unknown}" >&2
    exit 1
fi

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Vitals v85 $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$SENSORS" "$EXPECTED_SENSORS_SHA" "sensors.js"
check_sha "$PREFS_JS" "$EXPECTED_PREFS_JS_SHA" "prefs.js"
check_sha "$PREFS_UI" "$EXPECTED_PREFS_UI_SHA" "prefs.ui"

if [[ ! -f "$BACKUP_MO" ]]; then
    echo "FAIL: pristine Vitals v85 Polish catalog backup missing: $BACKUP_MO" >&2
    exit 1
fi

check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "upstream Polish catalog backup"
msgfmt --check "$OVERLAY" -o /dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/vitals.mo"

if ! cmp -s "$tmpdir/vitals.mo" "$TARGET_MO"; then
    echo "FAIL: installed Vitals v85 Polish catalog differs from repository completion" >&2
    exit 1
fi

completion_entries="$(grep -c '^msgid "' "$OVERLAY")"
completion_entries=$((completion_entries - 1))
printf 'Completion entries: %d\n' "$completion_entries"
echo "PASS: Vitals v85 Polish localization matches repository completion"
