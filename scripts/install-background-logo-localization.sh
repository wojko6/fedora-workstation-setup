#!/usr/bin/env bash
set -Eeuo pipefail

UUID="background-logo@fedorahosted.org"
EXT_DIR="/usr/share/gnome-shell/extensions/$UUID"
TARGET="$EXT_DIR/prefs.js"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT_DIR/patches/gnome-extensions/background-logo/prefs-pl.patch"

echo "=== POLISH LOCALIZATION: Background Logo ==="

if [[ ! -f "$TARGET" ]]; then
    echo "SKIP: Background Logo is not installed"
    exit 0
fi

if [[ ! -f "$PATCH" ]]; then
    echo "FAIL: localization patch missing: $PATCH"
    exit 1
fi

# Already patched?
if grep -q "Pokazuj na wszystkich tłach" "$TARGET" &&
   grep -q "Nazwa pliku (tryb ciemny)" "$TARGET"; then
    echo "PASS: Polish Background Logo localization already installed"
    exit 0
fi

# Never patch an incompatible upstream file.
if ! patch --dry-run --silent "$TARGET" "$PATCH" >/dev/null 2>&1; then
    echo "FAIL: patch is incompatible with the installed Background Logo"
    echo "The system file was not modified."
    exit 1
fi

BACKUP="${TARGET}.pre-polish.bak"

if [[ ! -f "$BACKUP" ]]; then
    echo "Creating upstream backup..."
    sudo cp -a "$TARGET" "$BACKUP"
fi

echo "Applying Polish localization..."
sudo patch --silent "$TARGET" "$PATCH"

if grep -q "Pokazuj na wszystkich tłach" "$TARGET" &&
   grep -q "Nazwa pliku (tryb ciemny)" "$TARGET"; then
    echo "PASS: Polish Background Logo localization installed"
else
    echo "FAIL: localization verification failed"
    exit 1
fi
