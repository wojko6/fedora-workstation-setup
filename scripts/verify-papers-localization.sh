#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="papers-nautilus"
EXPECTED_VERSION="49.8"
OVERLAY="$ROOT_DIR/localization/papers/pl-overlay.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/papers.mo"

for cmd in rpm msgfmt python3; do
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

tmp_mo="$(mktemp)"
trap 'rm -f "$tmp_mo"' EXIT
msgfmt --check "$OVERLAY" -o "$tmp_mo"

python3 - "$tmp_mo" "$TARGET_MO" <<'PY'
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

for path in sys.argv[1:]:
    with open(path, "rb") as fh:
        catalog = gettext.GNUTranslations(fh)
    for source, translated in expected.items():
        actual = catalog.gettext(source)
        if actual != translated:
            print(
                f"FAIL: {path}: {source!r}: expected {translated!r}, found {actual!r}",
                file=sys.stderr,
            )
            raise SystemExit(1)
PY

echo "PASS: Papers 49.8 Polish completion overlay and live catalog match"
