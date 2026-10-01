#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="tilingshell@ferrarodomenico.com"
DOMAIN="tilingshell"
EXPECTED_VERSION="76"
EXPECTED_VERSION_NAME="17.3"
EXPECTED_COMPLETION_ENTRIES="17"

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

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Tiling Shell extension not installed: $UUID"
    exit 0
fi

for cmd in \
    msgfmt msgunfmt msgcat msgattrib python3 sha256sum patch cmp
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command unavailable: $cmd" >&2
        exit 1
    }
done

for path in \
    "$SOURCE_PO" "$PATCH" "$TARGET_MO" "$BACKUP_MO" \
    "$METADATA" "$EDITOR" "$EDITOR_BACKUP"
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
check_sha "$EDITOR_BACKUP" "$EXPECTED_EDITOR_SHA" "pristine editorDialog.js backup"

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

entries="$(grep -c '^msgid "' "$SOURCE_PO")"
entries=$((entries - 1))

[[ "$entries" -eq "$EXPECTED_COMPLETION_ENTRIES" ]] || {
    echo "FAIL: expected $EXPECTED_COMPLETION_ENTRIES entries, found $entries" >&2
    exit 1
}

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

cmp -s \
    "$tmp/components/editor/editorDialog.js" \
    "$EDITOR" || {
        echo "FAIL: editorDialog.js differs from repository patch" >&2
        exit 1
    }

[[ "$(grep -Fc 'text: _("LEFT CLICK"),' "$EDITOR")" -eq 2 ]] || {
    echo "FAIL: LEFT CLICK gettext wiring missing" >&2
    exit 1
}

[[ "$(grep -Fc 'text: _("RIGHT CLICK"),' "$EDITOR")" -eq 1 ]] || {
    echo "FAIL: RIGHT CLICK gettext wiring missing" >&2
    exit 1
}

msgunfmt "$BACKUP_MO" -o "$tmp/upstream.po"

msgcat --use-first \
    "$SOURCE_PO" \
    "$tmp/upstream.po" \
    -o "$tmp/merged.po"

msgfmt --check --check-format \
    "$tmp/merged.po" \
    -o "$tmp/expected.mo"

cmp -s "$tmp/expected.mo" "$TARGET_MO" || {
    echo "FAIL: Tiling Shell Polish catalog differs from repository completion" >&2
    exit 1
}

untranslated="$(
    msgattrib --untranslated --no-obsolete "$tmp/merged.po" \
    | grep -c '^msgid ' || true
)"

fuzzy="$(
    msgattrib --only-fuzzy --no-obsolete "$tmp/merged.po" \
    | grep -c '^msgid ' || true
)"

[[ "$untranslated" -eq 0 && "$fuzzy" -eq 0 ]] || {
    echo "FAIL: merged catalog incomplete: untranslated=$untranslated fuzzy=$fuzzy" >&2
    exit 1
}

python3 - "$TARGET_MO" <<'PY'
import gettext
import sys

expected = {
    "LEFT CLICK": "LEWY PRZYCISK",
    "RIGHT CLICK": "PRAWY PRZYCISK",
}

with open(sys.argv[1], "rb") as f:
    catalog = gettext.GNUTranslations(f)

for source, wanted in expected.items():
    actual = catalog.gettext(source)

    if actual != wanted:
        raise SystemExit(
            f"FAIL: {source!r}: expected {wanted!r}, got {actual!r}"
        )

print("Tiling editor legend gettext checks: 2")
PY

echo "PASS: Tiling Shell 17.3 Polish localization matches repository completion ($EXPECTED_COMPLETION_ENTRIES entries, 0 fuzzy)"
