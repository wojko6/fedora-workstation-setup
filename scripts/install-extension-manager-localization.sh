#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

APP_ID="com.mattjakeman.ExtensionManager"
LOCALE_ID="com.mattjakeman.ExtensionManager.Locale"
DOMAIN="extension-manager"
EXPECTED_VERSION="0.6.5"
EXPECTED_LOCALE_COMMIT="9e45ce9096c3efdcc54b26375fed9b730a6e8f5032daf6b8cee35482afacd036"
EXPECTED_UPSTREAM_MO_SHA="6ea6fda169660bc791d46a74bd511cbb91a97ee6f9308bc9db7b4f3602d25a78"

OVERLAY="$ROOT_DIR/localization/extension-manager/v0.6.5-completion.po"
BACKUP_DIR="$HOME/.local/share/fedora-workstation-setup/extension-manager/v0.6.5"
BACKUP_MO="$BACKUP_DIR/$DOMAIN.mo.upstream.bak"
VERIFIER="$ROOT_DIR/scripts/verify-extension-manager-localization.sh"

for cmd in flatpak sha256sum msgfmt msgcat msgunfmt install python3 cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

if ! flatpak --system info "$APP_ID" >/dev/null 2>&1; then
    echo "SKIP: Extension Manager system Flatpak is not installed"
    exit 0
fi

if ! flatpak --system info "$LOCALE_ID" >/dev/null 2>&1; then
    echo "FAIL: Extension Manager Polish Locale ref is missing" >&2
    exit 1
fi

version="$(flatpak --system info --show-version "$APP_ID")"
if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Extension Manager version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
fi

locale_commit="$(flatpak --system info --show-commit "$LOCALE_ID")"
if [[ "$locale_commit" != "$EXPECTED_LOCALE_COMMIT" ]]; then
    echo "FAIL: Extension Manager Locale commit drift: expected $EXPECTED_LOCALE_COMMIT, found ${locale_commit:-unknown}" >&2
    exit 1
fi

locale_location="$(flatpak --system info --show-location "$LOCALE_ID")"
TARGET_MO="$locale_location/files/pl/share/pl/LC_MESSAGES/$DOMAIN.mo"

for path in "$OVERLAY" "$TARGET_MO" "$VERIFIER"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Extension Manager localization file missing: $path" >&2
        exit 1
    fi
done

msgfmt --check "$OVERLAY" -o /dev/null
mkdir -p "$BACKUP_DIR"

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Extension Manager $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"
    if [[ "$current_sha" != "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
        echo "FAIL: live Extension Manager Polish catalog is not the audited upstream artifact; refusing to overwrite" >&2
        echo "Found: $current_sha" >&2
        exit 1
    fi
    install -m 0644 "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
else
    check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "upstream Polish catalog backup"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"

python3 - "$tmpdir/$DOMAIN.mo" <<'PY'
import gettext
import sys

with open(sys.argv[1], "rb") as fh:
    tr = gettext.GNUTranslations(fh)

value = tr.pgettext("Sort search results", "None")
if value != "Brak":
    raise SystemExit(f"FAIL: contextual translation mismatch: {value!r}")
PY

if cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO"; then
    echo "PASS: Extension Manager 0.6.5 Polish completion already installed"
    bash "$VERIFIER"
    exit 0
fi

if [[ -w "$(dirname -- "$TARGET_MO")" ]]; then
    install -m 0644 "$tmpdir/$DOMAIN.mo" "$TARGET_MO"
else
    command -v sudo >/dev/null 2>&1 || {
        echo "FAIL: sudo is required to update the system Flatpak Locale deployment" >&2
        exit 1
    }
    sudo install -m 0644 "$tmpdir/$DOMAIN.mo" "$TARGET_MO"
    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon -F "$TARGET_MO" >/dev/null 2>&1 || true
    fi
fi

bash "$VERIFIER"
echo "PASS: Extension Manager 0.6.5 Polish completion installed"
echo "Close and reopen Extension Manager to reload the updated Locale catalog."
