#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="clipboard-indicator@tudmotu.com"
DOMAIN="clipboard-indicator"
EXPECTED_VERSION="71"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
EXTENSION_JS="$EXT_DIR/extension.js"
PREFS_JS="$EXT_DIR/prefs.js"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream-v71.bak"
OVERLAY="$ROOT_DIR/localization/clipboard-indicator/v71-completion.po"

EXPECTED_METADATA_SHA="a6eb46bc0f6aee7703b66885b0f7569b2b4c1681bacbe12d084b6789849276eb"
EXPECTED_EXTENSION_SHA="07efc321fbae6d47ad01cc7fbc3e91bcfb231be3dc267ecf431cd6638f273bf7"
EXPECTED_PREFS_SHA="c6128d7503eda7853dd01492e324246aac1a4834cdb020f37b8deee9ee5e275a"
EXPECTED_UPSTREAM_MO_SHA="312170de7c29483114d5cf41f540c66ce29fc4b273349144613af848897ab06f"
EXPECTED_COMPLETION_ENTRIES="63"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Clipboard Indicator extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt msgcat msgunfmt msgattrib cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

for path in "$METADATA" "$EXTENSION_JS" "$PREFS_JS" "$TARGET_MO" "$BACKUP_MO" "$OVERLAY"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Clipboard Indicator localization file missing: $path" >&2
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
    echo "FAIL: unexpected Clipboard Indicator version" >&2
    exit 1
fi

if [[ "${metadata_values[1]:-}" != "$DOMAIN" ]]; then
    echo "FAIL: unexpected Clipboard Indicator gettext-domain" >&2
    exit 1
fi

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Clipboard Indicator v71 $label fingerprint differs: $actual" >&2
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
    echo "FAIL: Clipboard Indicator completion entry count: expected $EXPECTED_COMPLETION_ENTRIES, found $completion_entries" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"

# gettext expects a standard locale directory layout beneath TEXTDOMAINDIR.
# Keep the flat compiled artifact for byte-for-byte comparison, and stage a
# second copy only for runtime gettext smoke tests.
mkdir -p "$tmpdir/locale/pl/LC_MESSAGES"
cp "$tmpdir/$DOMAIN.mo" "$tmpdir/locale/pl/LC_MESSAGES/$DOMAIN.mo"

if ! cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO"; then
    echo "FAIL: installed Clipboard Indicator v71 Polish catalog differs from repository completion" >&2
    exit 1
fi

untranslated="$(msgattrib --untranslated --no-obsolete "$tmpdir/merged.po" | grep -c '^msgid ' || true)"
fuzzy="$(msgattrib --only-fuzzy --no-obsolete "$tmpdir/merged.po" | grep -c '^msgid ' || true)"

if [[ "$untranslated" -ne 0 || "$fuzzy" -ne 0 ]]; then
    echo "FAIL: merged Clipboard Indicator Polish catalog is not complete (untranslated=$untranslated fuzzy=$fuzzy)" >&2
    exit 1
fi

for source in     "Reset Timer"     "Preview Image"     "Search"     "Show Search Bar"     "Case-sensitive"     "Regular expressions"     "Open menu at cursor"     "Item Actions"; do
    expected="$(LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 TEXTDOMAINDIR="$tmpdir/locale" gettext -d "$DOMAIN" "$source")"
    actual="$(LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 TEXTDOMAINDIR="$EXT_DIR/locale" gettext -d "$DOMAIN" "$source")"
    if [[ "$actual" != "$expected" || "$actual" == "$source" ]]; then
        echo "FAIL: Clipboard Indicator gettext smoke test failed for: $source" >&2
        exit 1
    fi
done

echo "PASS: Clipboard Indicator v71 Polish localization matches repository completion ($EXPECTED_COMPLETION_ENTRIES entries, 0 fuzzy)"
