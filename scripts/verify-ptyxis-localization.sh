#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="ptyxis"
EXPECTED_VERSION="50.1"
SOURCE_PO="$ROOT_DIR/localization/ptyxis/pl.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo"
LIBADWAITA_MO="/usr/share/locale/pl/LC_MESSAGES/libadwaita.mo"

for cmd in rpm msgfmt gettext cmp; do
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
    echo "FAIL: Ptyxis version drift: expected $EXPECTED_VERSION, found $version" >&2
    exit 1
fi

for path in "$SOURCE_PO" "$TARGET_MO" "$LIBADWAITA_MO"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required localization file missing: $path" >&2
        exit 1
    fi
done

tmp_mo="$(mktemp)"
trap 'rm -f "$tmp_mo"' EXIT
msgfmt --check "$SOURCE_PO" -o "$tmp_mo"

if ! cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "FAIL: live Ptyxis Polish catalog differs from repository catalog" >&2
    exit 1
fi

actual="$(
    LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 \
        gettext -d ptyxis '_About'
)"
if [[ "$actual" != "_O programie" ]]; then
    echo "FAIL: Ptyxis gettext domain is not active in Polish: found '$actual'" >&2
    exit 1
fi

while IFS='|' read -r source expected; do
    actual="$(
        LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 \
            gettext -d libadwaita "$source"
    )"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: libadwaita Polish string $source: expected '$expected', found '$actual'" >&2
        exit 1
    fi
done <<'EOF'
_Website|Str_ona programu
_Report an Issue|Zgłoś _błąd
_Troubleshooting|_Rozwiązywanie problemów
_Credits|_Zasługi
_Legal|_Kwestie prawne
EOF

echo "PASS: Ptyxis 50.1 main gettext domain and libadwaita Polish About-dialog strings are present"
