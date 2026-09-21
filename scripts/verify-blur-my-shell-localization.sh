#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="blur-my-shell@aunetx"
DOMAIN="blur-my-shell@aunetx"
EXPECTED_VERSION="72"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
EXTENSION_JS="$EXT_DIR/extension.js"
PREFS_JS="$EXT_DIR/prefs.js"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream-v72.bak"
OVERLAY="$ROOT_DIR/localization/blur-my-shell/v72-completion.po"

EXPECTED_METADATA_SHA="c361040062f3ce2918645a578f8d596d65ce728f8643c24400bd47857e3ff44e"
EXPECTED_EXTENSION_SHA="e8ed71fc608405dd1debada34a696ce82229e134113589f43b38a6c7f3117199"
EXPECTED_PREFS_SHA="6e2fb0d99630b2e621e7647a03f69ed1fad6aa197e32ae2e1b60c52342e65bc5"
EXPECTED_UPSTREAM_MO_SHA="44073c8675b6457082d9e3d7f40e8889259def344fe03b57155a115750493e88"
EXPECTED_COMPLETION_ENTRIES="46"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Blur my Shell extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt msgcat msgunfmt msgattrib gettext cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

for path in "$METADATA" "$EXTENSION_JS" "$PREFS_JS" "$TARGET_MO" "$BACKUP_MO" "$OVERLAY"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Blur my Shell localization file missing: $path" >&2
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

if [[ "${metadata_values[0]:-}" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: unexpected Blur my Shell version" >&2
    exit 1
fi

if [[ "${metadata_values[1]:-}" != "$DOMAIN" ]]; then
    echo "FAIL: unexpected Blur my Shell gettext-domain" >&2
    exit 1
fi

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Blur my Shell v72 $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$EXTENSION_JS" "$EXPECTED_EXTENSION_SHA" "extension.js"
check_sha "$PREFS_JS" "$EXPECTED_PREFS_SHA" "prefs.js"
check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "upstream Polish catalog backup"
msgfmt --check "$OVERLAY" -o /dev/null

completion_entries="$(grep -c '^msgid "' "$OVERLAY")"
completion_entries=$((completion_entries - 1))
if [[ "$completion_entries" -ne "$EXPECTED_COMPLETION_ENTRIES" ]]; then
    echo "FAIL: Blur my Shell completion entry count: expected $EXPECTED_COMPLETION_ENTRIES, found $completion_entries" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"
mkdir -p "$tmpdir/locale/pl/LC_MESSAGES"
cp "$tmpdir/$DOMAIN.mo" "$tmpdir/locale/pl/LC_MESSAGES/$DOMAIN.mo"

if ! cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO"; then
    echo "FAIL: installed Blur my Shell v72 Polish catalog differs from repository completion" >&2
    exit 1
fi

untranslated="$(msgattrib --untranslated --no-obsolete "$tmpdir/merged.po" | grep -c '^msgid ' || true)"
fuzzy="$(msgattrib --only-fuzzy --no-obsolete "$tmpdir/merged.po" | grep -c '^msgid ' || true)"

if [[ "$untranslated" -ne 0 || "$fuzzy" -ne 0 ]]; then
    echo "FAIL: merged Blur my Shell Polish catalog is not complete (untranslated=$untranslated fuzzy=$fuzzy)" >&2
    exit 1
fi

while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    expected="$(LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 TEXTDOMAINDIR="$tmpdir/locale" gettext -d "$DOMAIN" "$source")"
    actual="$(LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 TEXTDOMAINDIR="$EXT_DIR/locale" gettext -d "$DOMAIN" "$source")"
    if [[ "$actual" != "$expected" || "$actual" == "$source" ]]; then
        echo "FAIL: Blur my Shell gettext smoke test failed for: $source" >&2
        exit 1
    fi
done <<'EOF'
Prefer closer pixels
Blend mode
How the color is blended in.
Normal
Multiply
Screen
Overlay
Darken
Lighten
Plus darker
Plus lighter
Color dodge
Color burn
Hard light
Soft light
Difference
Exclusion
Hue
Saturation
Luminosity
An effect that affects the luminosity of the image.
Shift brightness
The brightness to add of remove to the image.
Multiply brightness
Contrast
The contrast of the image in regard to the center of the contrast.
Contrast center
The center of the contrast to use.
Boxcar
Dirac
Apply a spatial derivative, or a laplacian.
Operation
The mathematical operation to apply.
1-step derivative
2-step derivative
Laplacian
RGB to HSL (advanced effect)
Converts the image from RGBA colorspace to HSLA.
HSL to RGB (advanced effect)
Converts the image from HSLA colorspace to RGBA.
Corner radius
Radius for the corner rounding effect.
Enable corner rounding on maximized and fullscreen
Include advanced effects
Coverflow Alt-Tab extension blur
Make the coverflow alt-tab extension blurred, if it is used.
EOF

echo "PASS: Blur my Shell v72 Polish localization matches repository completion ($EXPECTED_COMPLETION_ENTRIES entries, 0 fuzzy)"
