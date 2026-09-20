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
KERNEL="$(uname -r)"
INITRAMFS="/boot/initramfs-${KERNEL}.img"
BACKUP_INITRAMFS="/var/tmp/initramfs-${KERNEL}-before-polish.img"

for cmd in rpm dracut lsinitrd python3 cmp grep sudo; do
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

required_files=(
    "$SOURCE_CONF"
    "$PLYMOUTH_MO"
    "$LOCALE_CONF"
    "/usr/lib/locale/C.utf8/LC_CTYPE"
    "/usr/lib/locale/pl_PL.utf8/LC_CTYPE"
    "/usr/lib/locale/pl_PL.utf8/LC_MESSAGES/SYS_LC_MESSAGES"
)

for path in "${required_files[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "FAIL: required Plymouth locale file missing: $path" >&2
        exit 1
    fi
done

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

changed=0
if [[ ! -f "$TARGET_CONF" ]] || ! cmp -s "$SOURCE_CONF" "$TARGET_CONF"; then
    sudo mkdir -p /etc/dracut.conf.d
    if [[ -f "$TARGET_CONF" && ! -f "${TARGET_CONF}.bak" ]]; then
        sudo cp -a "$TARGET_CONF" "${TARGET_CONF}.bak"
    fi
    sudo install -m 0644 "$SOURCE_CONF" "$TARGET_CONF"
    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon "$TARGET_CONF"
    fi
    changed=1
fi

initramfs_has_polish_state() {
    local listing locale_conf
    listing="$(sudo lsinitrd "$INITRAMFS" 2>/dev/null)" || return 1
    grep -Fq 'etc/locale.conf' <<<"$listing" || return 1
    grep -Fq 'usr/lib/locale/C.utf8/LC_CTYPE' <<<"$listing" || return 1
    grep -Fq 'usr/lib/locale/pl_PL.utf8/LC_CTYPE' <<<"$listing" || return 1
    grep -Fq 'usr/share/locale/pl/LC_MESSAGES/plymouth.mo' <<<"$listing" || return 1
    locale_conf="$(sudo lsinitrd -f /etc/locale.conf "$INITRAMFS" 2>/dev/null)" || return 1
    grep -Eq '^LANG="?pl_PL\.UTF-8"?$' <<<"$locale_conf"
}

if [[ ! -f "$INITRAMFS" ]]; then
    echo "FAIL: current initramfs not found: $INITRAMFS" >&2
    exit 1
fi

if (( changed )) || ! initramfs_has_polish_state; then
    if [[ ! -f "$BACKUP_INITRAMFS" ]]; then
        sudo cp -a "$INITRAMFS" "$BACKUP_INITRAMFS"
        echo "Backup: $BACKUP_INITRAMFS"
    fi

    echo "Rebuilding current initramfs with Polish Plymouth locale support..."
    sudo dracut --force "$INITRAMFS" "$KERNEL"
fi

if ! initramfs_has_polish_state; then
    echo "FAIL: rebuilt initramfs is missing required Polish Plymouth locale state" >&2
    exit 1
fi

echo "PASS: Plymouth Polish offline-update localization state installed in current initramfs"
