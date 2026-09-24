#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="gsconnect@andyholmes.github.io"
DOMAIN="org.gnome.Shell.Extensions.GSConnect"
EXPECTED_VERSION="73"
SOURCE_PO="$ROOT_DIR/localization/gsconnect/pl.po"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
METADATA="$EXT_DIR/metadata.json"
EXTENSION_JS="$EXT_DIR/extension.js"
PREFS_JS="$EXT_DIR/prefs.js"
CONFIG_JS="$EXT_DIR/config.js"
BACKUP_DIR="$EXT_DIR/.localization-backup-v73"
BACKUP_METADATA="$BACKUP_DIR/metadata.json"
BACKUP_MO="$BACKUP_DIR/$DOMAIN.mo"
VERIFIER="$ROOT_DIR/scripts/verify-gsconnect-localization.sh"

EXPECTED_METADATA_SHA="deb9d7972da0e973b3a67c910577dd2df1191b48fdd115a99288bcdb9c927422"
EXPECTED_EXTENSION_SHA="8de3ae0c1c4c1d0768c31aa8713192228168e988c3120eb3100a80d9f2b2feee"
EXPECTED_PREFS_SHA="d5c073a134d912411d4317d29e5a33131d71854471f58035cdb2cfabd3341e30"
EXPECTED_CONFIG_SHA="a90f3a914ab72bf7d72ce303008ef19c1904105abad691403172aeee996df6ee"
EXPECTED_UPSTREAM_MO_SHA="ac830d12a1e851b79438e18b5b6abf42cca6df10e02c176bba934af734235384"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: GSConnect extension not installed: $UUID"
    exit 0
fi

for cmd in msgfmt msgunfmt msgcat python3 sha256sum install cp cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$SOURCE_PO" "$TARGET_MO" "$METADATA" "$EXTENSION_JS" "$PREFS_JS" "$CONFIG_JS" "$VERIFIER"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required GSConnect localization file missing: $path" >&2
        exit 1
    }
done

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: GSConnect v73 $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$EXTENSION_JS" "$EXPECTED_EXTENSION_SHA" "extension.js"
check_sha "$PREFS_JS" "$EXPECTED_PREFS_SHA" "prefs.js"
check_sha "$CONFIG_JS" "$EXPECTED_CONFIG_SHA" "config.js"

readarray -t metadata_values < <(python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get("version", ""))
print(data.get("gettext-domain", ""))
PY
)

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

[[ "$version" == "$EXPECTED_VERSION" ]] || {
    echo "FAIL: GSConnect version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
}
[[ -z "$domain" || "$domain" == "$DOMAIN" ]] || {
    echo "FAIL: unexpected GSConnect gettext-domain: $domain" >&2
    exit 1
}

msgfmt --check "$SOURCE_PO" -o /dev/null

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$BACKUP_METADATA" ]]; then
    check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "pristine metadata.json"
    cp -a "$METADATA" "$BACKUP_METADATA"
    echo "Backup: $BACKUP_METADATA"
else
    check_sha "$BACKUP_METADATA" "$EXPECTED_METADATA_SHA" "pristine metadata backup"
fi

if [[ ! -f "$BACKUP_MO" ]]; then
    check_sha "$TARGET_MO" "$EXPECTED_UPSTREAM_MO_SHA" "upstream Polish catalog"
    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
else
    check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "pristine Polish catalog backup"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$BACKUP_METADATA" "$tmpdir/metadata.json" "$DOMAIN" <<'PY'
import json
import sys
src, dst, domain = sys.argv[1:]
with open(src, encoding="utf-8") as f:
    data = json.load(f)
current = data.get("gettext-domain")
if current is not None and current != domain:
    raise SystemExit(f"unexpected pristine gettext-domain: {current!r}")
data["gettext-domain"] = domain
with open(dst, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$SOURCE_PO" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"

install -m 0644 "$tmpdir/metadata.json" "$METADATA"
install -m 0644 "$tmpdir/$DOMAIN.mo" "$TARGET_MO"

bash "$VERIFIER"
echo "PASS: GSConnect v73 Polish completion and Shell gettext-domain fix installed"
echo "Sign out and back in to reload GSConnect Shell translations and metadata."
