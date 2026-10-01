#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGE="gnome-shell-extension-appindicator"
EXPECTED_NEVRA="gnome-shell-extension-appindicator-64-1.fc44.noarch"

UUID="appindicatorsupport@rgcjonas.gmail.com"
DOMAIN="AppIndicatorExtension"

EXT_DIR="/usr/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
GENERAL_PAGE="$EXT_DIR/preferences/generalPage.js"

TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/$DOMAIN.mo"
OVERLAY="$ROOT_DIR/localization/appindicator/v64-completion.po"
VERIFIER="$ROOT_DIR/scripts/verify-appindicator-localization.sh"

STATE_DIR="/var/lib/fedora-workstation-setup/appindicator/64-1.fc44"
BACKUP_MO="$STATE_DIR/$DOMAIN.mo.upstream"

EXPECTED_METADATA_SHA="b73e72861aba9b82b2913d14ae5921aeac87b8d19d161008194c68713a903b09"
EXPECTED_GENERAL_PAGE_SHA="eca50e44b09117c2e20793253b0a086d1a9d1b36506a0251b776592e057d4fe3"
EXPECTED_UPSTREAM_MO_SHA="0f8094b24b885ce3837c595bc09998324c4685954105e59c56cf9828d391b93b"

for cmd in \
    rpm sha256sum msgfmt msgunfmt msgcat msgattrib \
    python3 cmp install sudo
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command unavailable: $cmd" >&2
        exit 1
    }
done

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: AppIndicator package not installed"
    exit 0
fi

nevra="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$PACKAGE")"

[[ "$nevra" == "$EXPECTED_NEVRA" ]] || {
    echo "FAIL: AppIndicator package drift: expected $EXPECTED_NEVRA, found ${nevra:-unknown}" >&2
    exit 1
}

for path in \
    "$METADATA" "$GENERAL_PAGE" "$TARGET_MO" "$OVERLAY" "$VERIFIER"
do
    [[ -f "$path" ]] || {
        echo "FAIL: required AppIndicator localization file missing: $path" >&2
        exit 1
    }
done

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual

    actual="$(sha256sum "$path" | awk '{print $1}')"

    [[ "$actual" == "$expected" ]] || {
        echo "FAIL: AppIndicator $label fingerprint differs: $actual" >&2
        exit 1
    }
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$GENERAL_PAGE" "$EXPECTED_GENERAL_PAGE_SHA" "preferences/generalPage.js"

python3 - "$METADATA" "$DOMAIN" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

domain = data.get("gettext-domain")

if domain != sys.argv[2]:
    raise SystemExit(
        f"FAIL: unexpected AppIndicator gettext-domain: {domain!r}"
    )
PY

python3 - "$GENERAL_PAGE" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required = (
    "General",
    "Add X11 legacy tray icons to the panel area",
    "Compact Mode",
    "Puts tray indicators closer together",
    "Desaturation",
    "Icon Size",
    "Tray Horizontal Alignment",
)

for source in required:
    if source not in text:
        raise SystemExit(
            f"FAIL: audited AppIndicator source string missing: {source!r}"
        )

print(f"Audited source strings: {len(required)}")
PY

msgfmt --check --check-format "$OVERLAY" -o /dev/null

sudo install -d -m 0755 "$STATE_DIR"

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"

    if [[ "$current_sha" == "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
        sudo install -m 0644 "$TARGET_MO" "$BACKUP_MO"
        echo "Backup: $BACKUP_MO"
    else
        found=""

        shopt -s nullglob
        for candidate in "$HOME"/AppIndicatorExtension.mo.backup-*; do
            candidate_sha="$(sha256sum "$candidate" | awk '{print $1}')"

            if [[ "$candidate_sha" == "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
                [[ -z "$found" ]] || {
                    echo "FAIL: multiple pristine AppIndicator backup candidates found" >&2
                    exit 1
                }

                found="$candidate"
            fi
        done
        shopt -u nullglob

        [[ -n "$found" ]] || {
            echo "FAIL: live AppIndicator catalog is modified and no audited pristine backup was found" >&2
            echo "Current SHA: $current_sha" >&2
            exit 1
        }

        sudo install -m 0644 "$found" "$BACKUP_MO"

        echo "Recovered pristine catalog from: $found"
        echo "Backup: $BACKUP_MO"
    fi
fi

check_sha \
    "$BACKUP_MO" \
    "$EXPECTED_UPSTREAM_MO_SHA" \
    "pristine Polish catalog backup"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmp/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmp/upstream.po" \
    -o "$tmp/merged.po"

msgfmt --check --check-format \
    "$tmp/merged.po" \
    -o "$tmp/$DOMAIN.mo"

sudo install -m 0644 \
    "$tmp/$DOMAIN.mo" \
    "$TARGET_MO"

if command -v restorecon >/dev/null 2>&1; then
    sudo restorecon -F "$TARGET_MO" >/dev/null 2>&1 || true
fi

bash "$VERIFIER"

echo "PASS: AppIndicator v64 / Fedora 44 Polish completion installed"
echo "Close and reopen Extension Manager/preferences or sign out and back in to reload the catalog."
