#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="papers-nautilus"
EXPECTED_VERSION="49.8"
OVERLAY="$ROOT_DIR/localization/papers/pl-overlay.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/papers.mo"
BACKUP_MO="${TARGET_MO}.fedora-workstation-setup.upstream.bak"

for cmd in rpm msgfmt msgunfmt msgcat cmp python3 sudo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "FAIL: required package not installed: $PACKAGE" >&2
    exit 1
fi

version="$(rpm -q --qf '%{VERSION}\n' "$PACKAGE")"
if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Papers version drift: expected $EXPECTED_VERSION, found $version" >&2
    exit 1
fi

for path in "$OVERLAY" "$TARGET_MO"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Papers localization file missing: $path" >&2
        exit 1
    fi
done

msgfmt --check "$OVERLAY" -o /dev/null

catalog_has_completion() {
    python3 - "$1" <<'PY'
import gettext
import sys

expected = {
    "Document Properties": "Właściwości dokumentu",
    "Location": "Lokalizacja",
    "Author": "Autor",
    "Producer": "Producent",
    "Creator": "Twórca",
    "Created": "Utworzono",
    "Modified": "Zmodyfikowano",
    "Format": "Format",
    "Number of Pages": "Liczba stron",
    "Optimized": "Zoptymalizowany",
    "Security": "Zabezpieczenia",
    "Paper Size": "Rozmiar papieru",
    "Contains Javascript": "Zawiera JavaScript",
    "Size": "Rozmiar",
}

with open(sys.argv[1], "rb") as fh:
    catalog = gettext.GNUTranslations(fh)

bad = [
    (source, translated, catalog.gettext(source))
    for source, translated in expected.items()
    if catalog.gettext(source) != translated
]

if bad:
    for source, translated, actual in bad:
        print(f"mismatch: {source!r}: expected {translated!r}, found {actual!r}", file=sys.stderr)
    raise SystemExit(1)
PY
}

if catalog_has_completion "$TARGET_MO"; then
    echo "PASS: Papers Polish completion already installed"
    exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$TARGET_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/papers.mo"

if ! catalog_has_completion "$tmpdir/papers.mo"; then
    echo "FAIL: generated Papers Polish catalog does not contain the required completion" >&2
    exit 1
fi

if [[ ! -f "$BACKUP_MO" ]]; then
    sudo cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
fi

sudo install -m 0644 "$tmpdir/papers.mo" "$TARGET_MO"
if command -v restorecon >/dev/null 2>&1; then
    sudo restorecon "$TARGET_MO"
fi

if ! cmp -s "$tmpdir/papers.mo" "$TARGET_MO"; then
    echo "FAIL: installed Papers Polish catalog differs from generated catalog" >&2
    exit 1
fi

if command -v nautilus >/dev/null 2>&1; then
    nautilus -q >/dev/null 2>&1 || true
fi

echo "PASS: Papers / Nautilus document-properties Polish localization installed"
