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
VERIFIER="$ROOT_DIR/scripts/verify-clipboard-indicator-localization.sh"

EXPECTED_METADATA_SHA="a6eb46bc0f6aee7703b66885b0f7569b2b4c1681bacbe12d084b6789849276eb"
EXPECTED_EXTENSION_SHA="07efc321fbae6d47ad01cc7fbc3e91bcfb231be3dc267ecf431cd6638f273bf7"
EXPECTED_PREFS_SHA="c6128d7503eda7853dd01492e324246aac1a4834cdb020f37b8deee9ee5e275a"
EXPECTED_UPSTREAM_MO_SHA="312170de7c29483114d5cf41f540c66ce29fc4b273349144613af848897ab06f"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Clipboard Indicator extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt msgcat msgunfmt install; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

for path in "$METADATA" "$EXTENSION_JS" "$PREFS_JS" "$TARGET_MO" "$OVERLAY" "$VERIFIER"; do
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

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Clipboard Indicator version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
fi

if [[ "$domain" != "$DOMAIN" ]]; then
    echo "FAIL: Clipboard Indicator gettext domain drift: expected $DOMAIN, found ${domain:-unknown}" >&2
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
msgfmt --check "$OVERLAY" -o /dev/null

mkdir -p "$(dirname -- "$TARGET_MO")"

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"
    if [[ "$current_sha" != "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
        echo "FAIL: Clipboard Indicator v71 Polish catalog is not the audited upstream artifact; refusing to overwrite" >&2
        echo "Found: $current_sha" >&2
        exit 1
    fi
    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
else
    check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "upstream Polish catalog backup"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"
install -m 0644 "$tmpdir/$DOMAIN.mo" "$TARGET_MO"

bash "$VERIFIER"
echo "PASS: Clipboard Indicator v71 Polish completion installed"
echo "Sign out and back in, or restart the extension preferences process, to reload translations."
