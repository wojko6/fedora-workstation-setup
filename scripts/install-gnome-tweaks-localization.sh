#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGE="gnome-tweaks"
EXPECTED_NEVRA="gnome-tweaks-49.0-2.fc44.noarch"
EXPECTED_WIDGETS_SHA="2d1cba580bbfe37fd06244c76895f81c4358c2a2e2ece8c27a81cf0302d1ddca"
EXPECTED_MO_SHA="b6b9ec6189ff735a635cbc31aa6a709291a90ee73046970a185f136855209b65"

WIDGETS="/usr/lib/python3.14/site-packages/gtweak/widgets.py"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/gnome-tweaks.mo"
OVERLAY="$ROOT_DIR/localization/gnome-tweaks/v49.0-gsettings-enums.po"
PATCH_FILE="$ROOT_DIR/patches/gnome-tweaks/v49.0-gsettings-enum-gettext.patch"
VERIFIER="$ROOT_DIR/scripts/verify-gnome-tweaks-localization.sh"

STATE_DIR="/var/lib/fedora-workstation-setup/gnome-tweaks/49.0-2.fc44"
BACKUP_WIDGETS="$STATE_DIR/widgets.py.upstream"
BACKUP_MO="$STATE_DIR/gnome-tweaks.mo.upstream"

for cmd in rpm sha256sum msgfmt msgcat msgunfmt gettext patch cmp install sudo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: GNOME Tweaks is not installed"
    exit 0
fi

nevra="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$PACKAGE")"
if [[ "$nevra" != "$EXPECTED_NEVRA" ]]; then
    echo "FAIL: GNOME Tweaks package drift: expected $EXPECTED_NEVRA, found ${nevra:-unknown}" >&2
    exit 1
fi

for path in "$WIDGETS" "$TARGET_MO" "$OVERLAY" "$PATCH_FILE" "$VERIFIER"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required GNOME Tweaks localization file missing: $path" >&2
        exit 1
    fi
done

msgfmt --check "$OVERLAY" -o /dev/null
git_apply_check=0
if command -v git >/dev/null 2>&1; then
    git apply --numstat "$PATCH_FILE" >/dev/null
    git_apply_check=1
fi

sudo install -d -m 0755 "$STATE_DIR"

if [[ ! -f "$BACKUP_WIDGETS" ]]; then
    widgets_sha="$(sha256sum "$WIDGETS" | awk '{print $1}')"
    if [[ "$widgets_sha" != "$EXPECTED_WIDGETS_SHA" ]]; then
        echo "FAIL: GNOME Tweaks widgets.py is not the audited Fedora source; refusing to patch" >&2
        echo "Found: $widgets_sha" >&2
        exit 1
    fi
    sudo install -m 0644 "$WIDGETS" "$BACKUP_WIDGETS"
    echo "Backup: $BACKUP_WIDGETS"
else
    backup_widgets_sha="$(sha256sum "$BACKUP_WIDGETS" | awk '{print $1}')"
    if [[ "$backup_widgets_sha" != "$EXPECTED_WIDGETS_SHA" ]]; then
        echo "FAIL: GNOME Tweaks pristine widgets.py backup fingerprint differs: $backup_widgets_sha" >&2
        exit 1
    fi
fi

if [[ ! -f "$BACKUP_MO" ]]; then
    mo_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"
    if [[ "$mo_sha" != "$EXPECTED_MO_SHA" ]]; then
        echo "FAIL: GNOME Tweaks Polish catalog is not the audited Fedora artifact; refusing to replace" >&2
        echo "Found: $mo_sha" >&2
        exit 1
    fi
    sudo install -m 0644 "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
else
    backup_mo_sha="$(sha256sum "$BACKUP_MO" | awk '{print $1}')"
    if [[ "$backup_mo_sha" != "$EXPECTED_MO_SHA" ]]; then
        echo "FAIL: GNOME Tweaks pristine Polish catalog backup fingerprint differs: $backup_mo_sha" >&2
        exit 1
    fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/gtweak"
cp -a "$BACKUP_WIDGETS" "$tmpdir/gtweak/widgets.py"

if ! patch --dry-run --batch --forward -p1 -d "$tmpdir" <"$PATCH_FILE" >/dev/null; then
    echo "FAIL: GNOME Tweaks source patch does not apply cleanly to audited widgets.py" >&2
    exit 1
fi
patch --batch --forward -p1 -d "$tmpdir" <"$PATCH_FILE" >/dev/null

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/gnome-tweaks.mo"

sudo install -m 0644 "$tmpdir/gtweak/widgets.py" "$WIDGETS"
sudo install -m 0644 "$tmpdir/gnome-tweaks.mo" "$TARGET_MO"

if command -v restorecon >/dev/null 2>&1; then
    sudo restorecon -F "$WIDGETS" "$TARGET_MO" >/dev/null 2>&1 || true
fi

bash "$VERIFIER"

echo "PASS: GNOME Tweaks 49.0 Polish generated GSettings labels installed"
echo "Close all GNOME Tweaks windows and start the application again to reload the patched Python source and catalog."
