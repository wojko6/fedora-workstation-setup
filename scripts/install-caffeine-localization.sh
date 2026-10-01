#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="caffeine@patapon.info"
DOMAIN="gnome-shell-extension-caffeine"
EXPECTED_VERSION="60"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
DISPLAY_PAGE="$EXT_DIR/preferences/displayPage.js"
GENERAL_PAGE="$EXT_DIR/preferences/generalPage.js"

TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream-v60.bak"

OVERLAY="$ROOT_DIR/localization/caffeine/v60-completion.po"
VERIFIER="$ROOT_DIR/scripts/verify-caffeine-localization.sh"

EXPECTED_METADATA_SHA="3f0298b16c0f8999e12a11b14eb74532410d504743722e6cdc4b2eb98e1e4673"
EXPECTED_DISPLAY_SHA="f1011660035be026425acf6ff1609fa21ff242bc008c695b38c475c50320923c"
EXPECTED_GENERAL_SHA="586ce636ea9c3083cff93a40209194e66e153e15bc2310706ab61677c43cc896"
EXPECTED_UPSTREAM_MO_SHA="025c352644d419a61a8941383687ffd467e4f466d9c45b87a603f0f6fafcfe45"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Caffeine extension not installed"
    exit 0
fi

for cmd in \
    python3 sha256sum msgfmt msgunfmt msgcat install cp cmp
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

for path in \
    "$METADATA" \
    "$DISPLAY_PAGE" \
    "$GENERAL_PAGE" \
    "$TARGET_MO" \
    "$OVERLAY" \
    "$VERIFIER"
do
    [[ -f "$path" ]] || {
        echo "FAIL: required Caffeine localization file missing: $path" >&2
        exit 1
    }
done

readarray -t metadata_values < <(
    python3 - "$METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

print(data.get("version", ""))
print(data.get("gettext-domain", ""))
PY
)

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

[[ "$version" == "$EXPECTED_VERSION" ]] || {
    echo "FAIL: Caffeine version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
}

[[ "$domain" == "$DOMAIN" ]] || {
    echo "FAIL: Caffeine gettext-domain drift: expected $DOMAIN, found ${domain:-unknown}" >&2
    exit 1
}

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual

    actual="$(sha256sum "$path" | awk '{print $1}')"

    [[ "$actual" == "$expected" ]] || {
        echo "FAIL: Caffeine v60 $label fingerprint differs: $actual" >&2
        exit 1
    }
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$DISPLAY_PAGE" "$EXPECTED_DISPLAY_SHA" "preferences/displayPage.js"
check_sha "$GENERAL_PAGE" "$EXPECTED_GENERAL_SHA" "preferences/generalPage.js"

msgfmt --check --check-format "$OVERLAY" -o /dev/null

python3 - "$DISPLAY_PAGE" "$GENERAL_PAGE" <<'PY'
from pathlib import Path
import sys

display = Path(sys.argv[1]).read_text(encoding="utf-8")
general = Path(sys.argv[2]).read_text(encoding="utf-8")

required_display = (
    "Show quick settings toggle",
    "Enable or disable the toggle in the quick settings menu",
)

required_general = (
    "Enable when an app is playing media",
    "Automatically enable when an app reports playback",
    "Allow turning off screen when Caffeine is enabled",
    "This may disable manual suspend / shutdown",
)

for value in required_display:
    if value not in display:
        raise SystemExit(
            f"FAIL: Caffeine v60 displayPage.js source string missing: {value}"
        )

for value in required_general:
    if value not in general:
        raise SystemExit(
            f"FAIL: Caffeine v60 generalPage.js source string missing: {value}"
        )

print("PASS: Caffeine v60 audited source strings present")
PY

mkdir -p "$(dirname -- "$TARGET_MO")"

if [[ ! -f "$BACKUP_MO" ]]; then
    current_sha="$(sha256sum "$TARGET_MO" | awk '{print $1}')"

    if [[ "$current_sha" == "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
        cp -a "$TARGET_MO" "$BACKUP_MO"
        echo "Backup: $BACKUP_MO"
    else
        found_backup=""

        shopt -s nullglob
        for candidate in "${TARGET_MO}.backup-"*; do
            candidate_sha="$(sha256sum "$candidate" | awk '{print $1}')"

            if [[ "$candidate_sha" == "$EXPECTED_UPSTREAM_MO_SHA" ]]; then
                if [[ -n "$found_backup" ]]; then
                    echo "FAIL: multiple pristine Caffeine v60 backup candidates found" >&2
                    exit 1
                fi

                found_backup="$candidate"
            fi
        done
        shopt -u nullglob

        if [[ -z "$found_backup" ]]; then
            echo "FAIL: current Caffeine Polish catalog is not pristine and no audited pristine backup was found" >&2
            echo "Current SHA: $current_sha" >&2
            exit 1
        fi

        cp -a "$found_backup" "$BACKUP_MO"
        echo "Recovered pristine backup from: $found_backup"
        echo "Backup: $BACKUP_MO"
    fi
else
    check_sha \
        "$BACKUP_MO" \
        "$EXPECTED_UPSTREAM_MO_SHA" \
        "upstream Polish catalog backup"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmpdir/upstream.po" \
    -o "$tmpdir/merged.po"

msgfmt --check --check-format \
    "$tmpdir/merged.po" \
    -o "$tmpdir/$DOMAIN.mo"

install -m 0644 \
    "$tmpdir/$DOMAIN.mo" \
    "$TARGET_MO"

bash "$VERIFIER"

echo "PASS: Caffeine v60 Polish completion installed"
echo "Close and reopen Caffeine preferences to reload translations."
