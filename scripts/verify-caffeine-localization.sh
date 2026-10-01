#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="caffeine@patapon.info"
DOMAIN="gnome-shell-extension-caffeine"
EXPECTED_VERSION="60"
EXPECTED_COMPLETION_ENTRIES="5"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
DISPLAY_PAGE="$EXT_DIR/preferences/displayPage.js"
GENERAL_PAGE="$EXT_DIR/preferences/generalPage.js"

TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream-v60.bak"

OVERLAY="$ROOT_DIR/localization/caffeine/v60-completion.po"

EXPECTED_METADATA_SHA="3f0298b16c0f8999e12a11b14eb74532410d504743722e6cdc4b2eb98e1e4673"
EXPECTED_DISPLAY_SHA="f1011660035be026425acf6ff1609fa21ff242bc008c695b38c475c50320923c"
EXPECTED_GENERAL_SHA="586ce636ea9c3083cff93a40209194e66e153e15bc2310706ab61677c43cc896"
EXPECTED_UPSTREAM_MO_SHA="025c352644d419a61a8941383687ffd467e4f466d9c45b87a603f0f6fafcfe45"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Caffeine extension not installed"
    exit 0
fi

for cmd in \
    python3 sha256sum msgfmt msgunfmt msgcat cmp
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
    "$BACKUP_MO" \
    "$OVERLAY"
do
    [[ -f "$path" ]] || {
        echo "FAIL: required Caffeine localization file missing: $path" >&2
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
        echo "FAIL: Caffeine v60 $label fingerprint differs: $actual" >&2
        exit 1
    }
}

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

[[ "${metadata_values[0]:-}" == "$EXPECTED_VERSION" ]] || {
    echo "FAIL: unexpected Caffeine version" >&2
    exit 1
}

[[ "${metadata_values[1]:-}" == "$DOMAIN" ]] || {
    echo "FAIL: unexpected Caffeine gettext-domain" >&2
    exit 1
}

check_sha "$METADATA" "$EXPECTED_METADATA_SHA" "metadata.json"
check_sha "$DISPLAY_PAGE" "$EXPECTED_DISPLAY_SHA" "preferences/displayPage.js"
check_sha "$GENERAL_PAGE" "$EXPECTED_GENERAL_SHA" "preferences/generalPage.js"
check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "upstream Polish catalog backup"

msgfmt --check --check-format "$OVERLAY" -o /dev/null

completion_entries="$(
    grep -c '^msgid "' "$OVERLAY"
)"
completion_entries=$((completion_entries - 1))

[[ "$completion_entries" -eq "$EXPECTED_COMPLETION_ENTRIES" ]] || {
    echo "FAIL: Caffeine completion entry count: expected $EXPECTED_COMPLETION_ENTRIES, found $completion_entries" >&2
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgfmt \
    "$OVERLAY" \
    -o "$tmpdir/overlay.mo"

msgunfmt \
    "$BACKUP_MO" \
    -o "$tmpdir/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmpdir/upstream.po" \
    -o "$tmpdir/merged.po"

msgfmt --check --check-format \
    "$tmpdir/merged.po" \
    -o "$tmpdir/$DOMAIN.mo"

cmp -s "$tmpdir/$DOMAIN.mo" "$TARGET_MO" || {
    echo "FAIL: installed Caffeine v60 Polish catalog differs from repository completion" >&2
    exit 1
}

python3 - \
    "$BACKUP_MO" \
    "$tmpdir/overlay.mo" \
    "$TARGET_MO" <<'PY'
import gettext
import sys

upstream_path, overlay_path, installed_path = sys.argv[1:]

expected = {
    "Show quick settings toggle":
        "Pokaż przełącznik w szybkich ustawieniach",

    "Enable or disable the toggle in the quick settings menu":
        "Włącza lub wyłącza przełącznik w menu szybkich ustawień",

    "Enable when an app is playing media":
        "Włącz, gdy program odtwarza multimedia",

    "Automatically enable when an app reports playback":
        "Automatycznie włączaj, gdy program zgłasza odtwarzanie",

    "Allow turning off screen when Caffeine is enabled\n"
    "This may disable manual suspend / shutdown":
        "Zezwala na wygaszenie ekranu, gdy rozszerzenie Caffeine jest włączone\n"
        "Może to uniemożliwić ręczne usypianie / wyłączanie systemu",
}

with open(upstream_path, "rb") as f:
    upstream = gettext.GNUTranslations(f)

with open(overlay_path, "rb") as f:
    overlay = gettext.GNUTranslations(f)

with open(installed_path, "rb") as f:
    installed = gettext.GNUTranslations(f)

for source, translated in expected.items():
    upstream_value = upstream.gettext(source)

    if upstream_value != source:
        raise SystemExit(
            "FAIL: expected audited Caffeine v60 upstream gap for "
            f"{source!r}, got {upstream_value!r}"
        )

    overlay_value = overlay.gettext(source)
    installed_value = installed.gettext(source)

    if overlay_value != translated:
        raise SystemExit(
            f"FAIL: overlay translation mismatch for {source!r}: "
            f"{overlay_value!r}"
        )

    if installed_value != translated:
        raise SystemExit(
            f"FAIL: installed translation mismatch for {source!r}: "
            f"{installed_value!r}"
        )

print(f"Completion gettext checks: {len(expected)}")
PY

echo "PASS: Caffeine v60 Polish localization matches repository completion ($EXPECTED_COMPLETION_ENTRIES entries)"
