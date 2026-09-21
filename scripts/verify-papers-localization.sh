#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES=(papers papers-nautilus)
EXPECTED_VERSION="49.8"
OVERLAY="$ROOT_DIR/localization/papers/pl-overlay.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/papers.mo"
BACKUP_MO="${TARGET_MO}.fedora-workstation-setup.upstream.bak"

for cmd in rpm msgfmt msgunfmt msgcat cmp python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

for package in "${PACKAGES[@]}"; do
    if ! rpm -q "$package" >/dev/null 2>&1; then
        echo "FAIL: required package not installed: $package" >&2
        exit 1
    fi

    version="$(rpm -q --qf '%{VERSION}\n' "$package")"
    if [[ "$version" != "$EXPECTED_VERSION" ]]; then
        echo "FAIL: $package version drift: expected $EXPECTED_VERSION, found $version" >&2
        exit 1
    fi
done

for path in "$OVERLAY" "$TARGET_MO" "$BACKUP_MO"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Papers localization file missing: $path" >&2
        exit 1
    fi
done

msgfmt --check "$OVERLAY" -o /dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/expected-papers.mo"

if ! cmp -s "$tmpdir/expected-papers.mo" "$TARGET_MO"; then
    echo "FAIL: live Papers Polish catalog differs from byte-for-byte repository reconstruction" >&2
    exit 1
fi

python3 - "$TARGET_MO" <<'PY'
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
    "No Annotations": "Brak przypisów",
    "Open a Document": "Otwórz dokument",
    "Drag and drop documents here": "Przeciągnij i upuść dokumenty tutaj",
    "_Open…": "_Otwórz…",
}

with open(sys.argv[1], "rb") as fh:
    catalog = gettext.GNUTranslations(fh)

for source, translated in expected.items():
    actual = catalog.gettext(source)
    if actual != translated:
        print(
            f"FAIL: {source!r}: expected {translated!r}, found {actual!r}",
            file=sys.stderr,
        )
        raise SystemExit(1)
PY

echo "PASS: Papers 49.8 live Polish catalog matches byte-for-byte repository reconstruction"
