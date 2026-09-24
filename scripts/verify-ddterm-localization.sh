#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="ddterm@amezin.github.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
PANELICON="$EXT_DIR/ddterm/shell/panelicon.js"
ABOUT_JS="$EXT_DIR/ddterm/app/about.js"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$UUID.mo"
BACKUP_DIR="$EXT_DIR/.localization-backup-v73"
BACKUP_METADATA="$BACKUP_DIR/metadata.json"
BACKUP_MO="$BACKUP_DIR/$UUID.mo"
OVERLAY="$ROOT_DIR/localization/ddterm/v73-completion.po"

EXPECTED_VERSION="73"
EXPECTED_DOMAIN="$UUID"
EXPECTED_DESCRIPTION="Rozwijany terminal dla GNOME Shell z obsługą kart. Działa natywnie w Waylandzie"
EXPECTED_METADATA_SHA="929c083f90f50813dbc17b3ac177fb7ed036328e26fc80651c38cf1d1d5b1f85"
EXPECTED_PANELICON_SHA="92bd4daa7a90413d8c9ff83f4f85303e43f323603682ac97e722db90ceaff442"
EXPECTED_ABOUT_SHA="574246b0505bcc791b819dd0b0aa550552c0b2022f8d95cec320eab14437a03e"
EXPECTED_UPSTREAM_MO_SHA="37754ae9fa4b614dae7a9c503df1e2b9ff6ea604150ae9b23e5782460f5007d7"
EXPECTED_COMPLETION_ENTRIES="18"
UPSTREAM_DESCRIPTION="Another drop down terminal extension for GNOME Shell. With tabs. Works on Wayland natively"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: ddterm extension not installed"
    exit 0
fi

for cmd in python3 sha256sum msgfmt msgcat msgunfmt cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in "$METADATA" "$PANELICON" "$ABOUT_JS" "$TARGET_MO" "$BACKUP_METADATA" "$BACKUP_MO" "$OVERLAY"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required ddterm localization file missing: $path" >&2
        exit 1
    }
done

readarray -t metadata_values < <(python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('version', ''))
print(data.get('gettext-domain', ''))
print(data.get('description', ''))
PY
)

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"
description="${metadata_values[2]:-}"

[[ "$version" == "$EXPECTED_VERSION" ]] || {
    echo "FAIL: ddterm version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
}
[[ "$domain" == "$EXPECTED_DOMAIN" ]] || {
    echo "FAIL: ddterm gettext domain drift: expected $EXPECTED_DOMAIN, found ${domain:-unknown}" >&2
    exit 1
}
[[ "$description" == "$EXPECTED_DESCRIPTION" ]] || {
    echo "FAIL: ddterm localized metadata description differs" >&2
    exit 1
}

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: ddterm v73 $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$PANELICON" "$EXPECTED_PANELICON_SHA" "panelicon.js"
check_sha "$ABOUT_JS" "$EXPECTED_ABOUT_SHA" "about.js"
check_sha "$BACKUP_METADATA" "$EXPECTED_METADATA_SHA" "pristine metadata backup"
check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "pristine Polish catalog backup"
msgfmt --check "$OVERLAY" -o /dev/null

completion_entries="$(grep -c '^msgid "' "$OVERLAY")"
completion_entries=$((completion_entries - 1))
[[ "$completion_entries" -eq "$EXPECTED_COMPLETION_ENTRIES" ]] || {
    echo "FAIL: unexpected ddterm completion entry count: $completion_entries" >&2
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$BACKUP_METADATA" "$tmpdir/metadata.json" "$UPSTREAM_DESCRIPTION" "$EXPECTED_DESCRIPTION" <<'PY'
from pathlib import Path
import sys
src, dst, old, new = sys.argv[1:]
text = Path(src).read_text(encoding='utf-8')
if text.count(old) != 1:
    raise SystemExit('unexpected ddterm upstream description occurrence count')
Path(dst).write_text(text.replace(old, new, 1), encoding='utf-8')
PY

if ! cmp -s "$tmpdir/metadata.json" "$METADATA"; then
    echo "FAIL: installed ddterm metadata differs from repository localization" >&2
    exit 1
fi

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$UUID.mo"

if ! cmp -s "$tmpdir/$UUID.mo" "$TARGET_MO"; then
    echo "FAIL: installed ddterm Polish catalog differs from repository completion" >&2
    exit 1
fi

printf 'Completion entries: %d\n' "$completion_entries"
echo "PASS: ddterm v73 full Polish localization and metadata description match repository"
