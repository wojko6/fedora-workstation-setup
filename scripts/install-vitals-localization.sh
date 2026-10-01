#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="Vitals@CoreCoding.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"

METADATA="$EXT_DIR/metadata.json"
SENSORS="$EXT_DIR/sensors.js"
VALUES="$EXT_DIR/values.js"
PREFS_JS="$EXT_DIR/prefs.js"
PREFS_UI="$EXT_DIR/prefs.ui"

TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/vitals.mo"
BACKUP_MO="${TARGET_MO}.upstream-v85.bak"
BACKUP_VALUES="${VALUES}.upstream-v85.bak"

OVERLAY="$ROOT_DIR/localization/vitals/v85-completion.po"
VALUES_PATCH="$ROOT_DIR/patches/gnome-extensions/vitals/v85-values-gettext.patch"
VERIFIER="$ROOT_DIR/scripts/verify-vitals-localization.sh"

EXPECTED_VERSION="85"
EXPECTED_DOMAIN="vitals"

EXPECTED_METADATA_SHA="44a7e4b91c747b8ff3c1dfd8fb28e0dcf1564a36c7bd8cdb60bebc4826de8604"
EXPECTED_SENSORS_SHA="44a12381e932005c3a7272a14c9e5b3d6f7b320aba022ce7a1b29f67dd1e878c"
EXPECTED_VALUES_SHA="77aa46946e8cabec67dea2263e749308150b424612537e7c5af346d16751bcaf"
EXPECTED_PREFS_JS_SHA="b7e0a29d7f36d65fbb50f53d15fa2f3dfd00eb600a257d59581f0ff592a94149"
EXPECTED_PREFS_UI_SHA="3691d198899a1269820f7c074730b3c7a2158ddc359a4c9131bacb4b0d8182f4"
EXPECTED_UPSTREAM_MO_SHA="107547ee28ae386bf1b609f55861a1977a23f100d5931f0c49e996869c17e2d2"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual

    actual="$(sha256sum "$path" | awk '{print $1}')"

    [[ "$actual" == "$expected" ]] ||
        die "Vitals v85 $label fingerprint differs: $actual"
}

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Vitals extension not installed"
    exit 0
fi

for cmd in \
    python3 sha256sum msgfmt msgcat msgunfmt \
    install patch cmp cp
do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "required command not found: $cmd"
done

for path in \
    "$METADATA" \
    "$SENSORS" \
    "$VALUES" \
    "$PREFS_JS" \
    "$PREFS_UI" \
    "$OVERLAY" \
    "$VALUES_PATCH" \
    "$TARGET_MO" \
    "$VERIFIER"
do
    [[ -f "$path" ]] ||
        die "required Vitals localization file missing: $path"
done

readarray -t metadata_values < <(
    python3 - "$METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

print(data.get("version", ""))
print(data.get("gettext-domain", ""))
PY
)

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

[[ "$version" == "$EXPECTED_VERSION" ]] ||
    die "Vitals version drift: expected $EXPECTED_VERSION, found ${version:-unknown}"

[[ "$domain" == "$EXPECTED_DOMAIN" ]] ||
    die "Vitals gettext domain drift: expected $EXPECTED_DOMAIN, found ${domain:-unknown}"

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$SENSORS" "$EXPECTED_SENSORS_SHA" "sensors.js"
check_sha "$PREFS_JS" "$EXPECTED_PREFS_JS_SHA" "prefs.js"
check_sha "$PREFS_UI" "$EXPECTED_PREFS_UI_SHA" "prefs.ui"

msgfmt --check --check-format "$OVERLAY" -o /dev/null

echo "=== VITALS PRISTINE VALUES.JS ==="

if [[ ! -f "$BACKUP_VALUES" ]]; then
    check_sha "$VALUES" "$EXPECTED_VALUES_SHA" "pristine values.js"
    cp -a "$VALUES" "$BACKUP_VALUES"
    echo "Backup: $BACKUP_VALUES"
else
    check_sha "$BACKUP_VALUES" "$EXPECTED_VALUES_SHA" \
        "upstream values.js backup"
fi

echo
echo "=== VITALS PRISTINE POLISH CATALOG ==="

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"

    [[ "$current_sha" == "$EXPECTED_UPSTREAM_MO_SHA" ]] ||
        die "Polish catalog is not the audited upstream artifact; refusing to overwrite (found $current_sha)"

    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
else
    check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" \
        "upstream Polish catalog backup"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo
echo "=== BUILD PATCHED VALUES.JS ==="

cp -a "$BACKUP_VALUES" "$tmpdir/values.js"

patch --dry-run --batch --forward \
    -p1 \
    -d "$tmpdir" \
    < "$VALUES_PATCH" \
    >/dev/null

patch --batch --forward \
    -p1 \
    -d "$tmpdir" \
    < "$VALUES_PATCH" \
    >/dev/null

grep -Fq \
    "import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';" \
    "$tmpdir/values.js" ||
    die "gettext import missing from reconstructed values.js"

grep -Fq \
    "return { text: _('N/A'), style: '' };" \
    "$tmpdir/values.js" ||
    die "N/A gettext wiring missing from reconstructed values.js"

if grep -Fq \
    "return { text: 'N/A', style: '' };" \
    "$tmpdir/values.js"
then
    die "hard-coded displayed N/A remains in reconstructed values.js"
fi

echo "PASS: reconstructed values.js uses gettext for displayed N/A"

echo
echo "=== BUILD POLISH CATALOG ==="

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmpdir/upstream.po" \
    -o "$tmpdir/merged.po"

msgfmt --check --check-format \
    "$tmpdir/merged.po" \
    -o "$tmpdir/vitals.mo"

python3 - "$tmpdir/merged.po" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

expected = {
    "N/A": "Brak danych",
    "Average": "Średnia",
    "Minimum": "Minimum",
    "Maximum": "Maksimum",
}

for msgid, msgstr in expected.items():
    pattern = (
        r'^msgid "' + re.escape(msgid) + r'"\n'
        r'msgstr "' + re.escape(msgstr) + r'"$'
    )
    if not re.search(pattern, text, flags=re.MULTILINE):
        raise SystemExit(
            f"FAIL: merged Vitals catalog lacks {msgid!r} -> {msgstr!r}"
        )

print("PASS: four targeted Vitals translations are present")
PY

echo
echo "=== INSTALL ==="

install -m 0644 \
    "$tmpdir/values.js" \
    "$VALUES"

install -m 0644 \
    "$tmpdir/vitals.mo" \
    "$TARGET_MO"

echo
echo "=== VERIFY ==="

bash "$VERIFIER"

echo "PASS: Vitals v85 Polish completion installed"
echo "VITALS_INSTALL=PASS"
