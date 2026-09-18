#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="gnome-shell-extension-appindicator"
EXPECTED_PACKAGE_VERSION="64-1.fc44"
UUID="appindicatorsupport@rgcjonas.gmail.com"
EXT_DIR="/usr/share/gnome-shell/extensions/$UUID"
DOMAIN="AppIndicatorExtension"
OVERLAY_PO="$ROOT_DIR/localization/appindicator/pl.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream-v64-1.fc44.bak"

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: AppIndicator package not installed"
    exit 0
fi

for cmd in rpm python3 msgfmt msgunfmt msgcat cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

package_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$PACKAGE")"
if [[ "$package_version" != "$EXPECTED_PACKAGE_VERSION" ]]; then
    echo "FAIL: AppIndicator localization is pinned to $EXPECTED_PACKAGE_VERSION; installed package is $package_version" >&2
    exit 1
fi

[[ -d "$EXT_DIR" ]] || {
    echo "FAIL: AppIndicator extension directory missing" >&2
    exit 1
}
[[ -f "$EXT_DIR/metadata.json" ]] || {
    echo "FAIL: AppIndicator metadata missing" >&2
    exit 1
}
[[ -f "$OVERLAY_PO" ]] || {
    echo "FAIL: AppIndicator Polish completion overlay missing" >&2
    exit 1
}
[[ -f "$BACKUP_MO" ]] || {
    echo "FAIL: AppIndicator pristine Polish catalog backup missing" >&2
    exit 1
}
[[ -f "$TARGET_MO" ]] || {
    echo "FAIL: installed AppIndicator Polish catalog missing" >&2
    exit 1
}

if ! grep -Fq '"gettext-domain": "AppIndicatorExtension"' "$EXT_DIR/metadata.json"; then
    echo "FAIL: unexpected AppIndicator gettext domain" >&2
    exit 1
fi

msgfmt --check "$OVERLAY_PO" -o /dev/null

overlay_entries="$(python3 - "$OVERLAY_PO" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8')
entries = re.findall(r'^msgid "(.+)"\nmsgstr "(.+)"$', text, flags=re.M)
print(sum(1 for msgid, msgstr in entries if msgid and msgstr))
PY
)"
if [[ "$overlay_entries" != "5" ]]; then
    echo "FAIL: unexpected AppIndicator completion entry count: $overlay_entries" >&2
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
base_po="$tmp_dir/base.po"
merged_po="$tmp_dir/merged.po"
expected_mo="$tmp_dir/$DOMAIN.mo"

msgunfmt "$BACKUP_MO" -o "$base_po"
msgcat --use-first "$OVERLAY_PO" "$base_po" -o "$merged_po"
msgfmt --check "$merged_po" -o "$expected_mo"

if ! cmp -s "$expected_mo" "$TARGET_MO"; then
    echo "FAIL: AppIndicator Polish catalog differs from repository completion" >&2
    exit 1
fi

echo "Completion entries: $overlay_entries"
echo "PASS: AppIndicator v64 Polish localization matches repository completion"
