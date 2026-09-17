#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="gsconnect@andyholmes.github.io"
DOMAIN="org.gnome.Shell.Extensions.GSConnect"
SOURCE_PO="$ROOT_DIR/localization/gsconnect/pl.po"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream.bak"

for cmd in msgfmt msgunfmt msgcat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: $cmd not found (install gettext)" >&2
        exit 1
    fi
done

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: GSConnect extension not installed: $UUID"
    exit 0
fi

if [[ ! -f "$SOURCE_PO" ]]; then
    echo "FAIL: missing repository GSConnect localization source" >&2
    exit 1
fi

if [[ ! -f "$TARGET_MO" ]]; then
    echo "FAIL: installed GSConnect Polish catalog missing" >&2
    exit 1
fi

if [[ ! -f "$BACKUP_MO" ]]; then
    echo "FAIL: GSConnect upstream catalog backup missing; run install-gsconnect-localization.sh" >&2
    exit 1
fi

msgfmt --check "$SOURCE_PO" -o /dev/null

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmp_dir/upstream.po"
msgcat --use-first \
    "$SOURCE_PO" \
    "$tmp_dir/upstream.po" \
    -o "$tmp_dir/merged.po"
msgfmt --check "$tmp_dir/merged.po" -o "$tmp_dir/expected.mo"

if cmp -s "$tmp_dir/expected.mo" "$TARGET_MO"; then
    echo "PASS: GSConnect Polish localization matches repository completion"
else
    echo "FAIL: GSConnect Polish localization differs from repository completion" >&2
    exit 1
fi
