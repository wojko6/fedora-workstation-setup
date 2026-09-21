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
BACKUP_MO="$HOME/.local/share/fedora-workstation-setup/extension-manager/v0.6.5/$DOMAIN.mo.upstream.bak"

if ! flatpak --system info "$APP_ID" >/dev/null 2>&1; then
    echo "SKIP: Extension Manager system Flatpak is not installed"
    exit 0
fi

for cmd in flatpak sha256sum msgfmt msgcat msgunfmt python3 cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

if ! flatpak --system info "$LOCALE_ID" >/dev/null 2>&1; then
    echo "FAIL: Extension Manager Polish Locale ref is missing" >&2
    exit 1
fi

version="$(
    LC_ALL=C flatpak --system info "$APP_ID" |
        sed -nE 's/^[[:space:]]*Version:[[:space:]]*//p' |
        head -n 1
)"
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

for path in "$OVERLAY" "$BACKUP_MO" "$TARGET_MO"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Extension Manager localization file missing: $path" >&2
        exit 1
    fi
done

backup_sha="$(sha256sum "$BACKUP_MO" | awk '{print $1}')"
if [[ "$backup_sha" != "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
    echo "FAIL: Extension Manager upstream catalog backup fingerprint differs: $backup_sha" >&2
    exit 1
fi

msgfmt --check "$OVERLAY" -o /dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"

if ! cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO"; then
    echo "FAIL: live Extension Manager Polish catalog differs from repository completion" >&2
    exit 1
fi

python3 - "$TARGET_MO" <<'PY'
import gettext
import sys

with open(sys.argv[1], "rb") as fh:
    tr = gettext.GNUTranslations(fh)

tests = {
    ("Sort search results", "None"): "Brak",
}

for (context, msgid), expected in tests.items():
    actual = tr.pgettext(context, msgid)
    if actual != expected:
        raise SystemExit(
            f"FAIL: Extension Manager contextual gettext mismatch for {context!r}/{msgid!r}: "
            f"{actual!r} != {expected!r}"
        )
PY

echo "PASS: Extension Manager 0.6.5 Polish localization matches repository completion (None -> Brak)"
