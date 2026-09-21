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
VERIFIER="$ROOT_DIR/scripts/verify-blur-my-shell-localization.sh"

EXPECTED_METADATA_SHA="c361040062f3ce2918645a578f8d596d65ce728f8643c24400bd47857e3ff44e"
EXPECTED_EXTENSION_SHA="e8ed71fc608405dd1debada34a696ce82229e134113589f43b38a6c7f3117199"
EXPECTED_PREFS_SHA="6e2fb0d99630b2e621e7647a03f69ed1fad6aa197e32ae2e1b60c52342e65bc5"
EXPECTED_UPSTREAM_MO_SHA="44073c8675b6457082d9e3d7f40e8889259def344fe03b57155a115750493e88"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Blur my Shell extension not installed"
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

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Blur my Shell version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
fi

if [[ "$domain" != "$DOMAIN" ]]; then
    echo "FAIL: Blur my Shell gettext domain drift: expected $DOMAIN, found ${domain:-unknown}" >&2
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
msgfmt --check "$OVERLAY" -o /dev/null

mkdir -p "$(dirname -- "$TARGET_MO")"

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"
    if [[ "$current_sha" != "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
        echo "FAIL: Blur my Shell v72 Polish catalog is not the audited upstream artifact; refusing to overwrite" >&2
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
echo "PASS: Blur my Shell v72 Polish completion installed"
echo "Sign out and back in, or restart the extension preferences process, to reload translations."
