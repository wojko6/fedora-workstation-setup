#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="plymouth"
EXPECTED_VERSION="24.004.60"
LANGPACK="glibc-langpack-pl"
SOURCE_CONF="$ROOT_DIR/localization/plymouth/55-polish-plymouth.conf"
TARGET_CONF="/etc/dracut.conf.d/55-polish-plymouth.conf"
PLYMOUTH_MO="/usr/share/locale/pl/LC_MESSAGES/plymouth.mo"
LOCALE_CONF="/etc/locale.conf"
INITRAMFS="/boot/initramfs-$(uname -r).img"

for cmd in rpm python3 cmp grep; do
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
    echo "FAIL: Plymouth version drift: expected $EXPECTED_VERSION, found $version" >&2
    exit 1
fi

if ! rpm -q "$LANGPACK" >/dev/null 2>&1; then
    echo "FAIL: required package not installed: $LANGPACK" >&2
    exit 1
fi

for path in "$SOURCE_CONF" "$TARGET_CONF" "$PLYMOUTH_MO" "$LOCALE_CONF"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Plymouth localization file missing: $path" >&2
        exit 1
    fi
done

if ! cmp -s "$SOURCE_CONF" "$TARGET_CONF"; then
    echo "FAIL: persistent dracut Plymouth localization config differs from repository" >&2
    exit 1
fi

if ! grep -Eq '^LANG="?pl_PL\.UTF-8"?$' "$LOCALE_CONF"; then
    echo "FAIL: system locale is not LANG=pl_PL.UTF-8" >&2
    exit 1
fi

python3 - "$PLYMOUTH_MO" <<'PY'
import gettext
import sys

expected = {
    "Installing Updates...": "Instalowanie aktualizacji…",
    "Do not turn off your computer": "Nie należy wyłączać komputera",
    "%d%% complete": "Ukończono %d%%",
}

with open(sys.argv[1], "rb") as fh:
    catalog = gettext.GNUTranslations(fh)

for source, translated in expected.items():
    actual = catalog.gettext(source)
    if actual != translated:
        print(
            f"FAIL: Plymouth catalog: {source!r}: expected {translated!r}, found {actual!r}",
            file=sys.stderr,
        )
        raise SystemExit(1)
PY

for path in     /usr/lib/locale/C.utf8/LC_CTYPE     /usr/lib/locale/pl_PL.utf8/LC_CTYPE     /usr/lib/locale/pl_PL.utf8/LC_MESSAGES/SYS_LC_MESSAGES; do
    if [[ ! -e "$path" ]]; then
        echo "FAIL: required locale artifact missing: $path" >&2
        exit 1
    fi
done

if [[ -r "$INITRAMFS" ]] && command -v lsinitrd >/dev/null 2>&1; then
    listing="$(lsinitrd "$INITRAMFS" 2>/dev/null || true)"
    for path in         etc/locale.conf         usr/lib/locale/C.utf8/LC_CTYPE         usr/lib/locale/pl_PL.utf8/LC_CTYPE         usr/share/locale/pl/LC_MESSAGES/plymouth.mo; do
        if ! grep -Fq "$path" <<<"$listing"; then
            echo "FAIL: readable current initramfs is missing: $path" >&2
            exit 1
        fi
    done
else
    echo "INFO: current initramfs is not user-readable; persistent dracut state verified"
fi

echo "PASS: Plymouth Polish offline-update localization persistent state matches repository"
