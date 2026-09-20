#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="ptyxis"
EXPECTED_VERSION="50.1"
SOURCE_PO="$ROOT_DIR/localization/ptyxis/pl.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo"
BACKUP_MO="${TARGET_MO}.fedora-workstation-setup.upstream.bak"

for cmd in rpm msgfmt gettext cmp sudo; do
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

if [[ ! -f "$SOURCE_PO" ]]; then
    echo "FAIL: missing Ptyxis Polish catalog source: $SOURCE_PO" >&2
    exit 1
fi

tmp_mo="$(mktemp)"
trap 'rm -f "$tmp_mo"' EXIT

msgfmt --check "$SOURCE_PO" -o "$tmp_mo"

if [[ -f "$TARGET_MO" ]] && cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "PASS: Ptyxis 50.1 Polish localization bridge already installed"
    exit 0
fi

if [[ -f "$TARGET_MO" && ! -f "$BACKUP_MO" ]]; then
    sudo cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
fi

sudo install -D -m 0644 "$tmp_mo" "$TARGET_MO"
if command -v restorecon >/dev/null 2>&1; then
    sudo restorecon "$TARGET_MO"
fi

if ! cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "FAIL: installed Ptyxis Polish catalog differs from repository catalog" >&2
    exit 1
fi

actual="$(
    LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 \
        gettext -d ptyxis '_About'
)"
if [[ "$actual" != "_O programie" ]]; then
    echo "FAIL: Ptyxis gettext smoke test: expected '_O programie', found '$actual'" >&2
    exit 1
fi

echo "PASS: Ptyxis 50.1 Polish localization bridge installed"
echo "INFO: start a new Ptyxis process to refresh libadwaita About-dialog strings"
