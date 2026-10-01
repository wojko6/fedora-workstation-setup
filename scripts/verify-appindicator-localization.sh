#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGE="gnome-shell-extension-appindicator"
EXPECTED_NEVRA="gnome-shell-extension-appindicator-64-1.fc44.noarch"

UUID="appindicatorsupport@rgcjonas.gmail.com"
DOMAIN="AppIndicatorExtension"
EXPECTED_COMPLETION_ENTRIES="7"

EXT_DIR="/usr/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
GENERAL_PAGE="$EXT_DIR/preferences/generalPage.js"

TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/$DOMAIN.mo"
OVERLAY="$ROOT_DIR/localization/appindicator/v64-completion.po"

STATE_DIR="/var/lib/fedora-workstation-setup/appindicator/64-1.fc44"
BACKUP_MO="$STATE_DIR/$DOMAIN.mo.upstream"

EXPECTED_METADATA_SHA="b73e72861aba9b82b2913d14ae5921aeac87b8d19d161008194c68713a903b09"
EXPECTED_GENERAL_PAGE_SHA="eca50e44b09117c2e20793253b0a086d1a9d1b36506a0251b776592e057d4fe3"
EXPECTED_UPSTREAM_MO_SHA="0f8094b24b885ce3837c595bc09998324c4685954105e59c56cf9828d391b93b"

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: AppIndicator package not installed"
    exit 0
fi

for cmd in \
    rpm sha256sum msgfmt msgunfmt msgcat msgattrib python3 cmp
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command unavailable: $cmd" >&2
        exit 1
    }
done

nevra="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$PACKAGE")"

[[ "$nevra" == "$EXPECTED_NEVRA" ]] || {
    echo "FAIL: AppIndicator package drift: expected $EXPECTED_NEVRA, found ${nevra:-unknown}" >&2
    exit 1
}

for path in \
    "$METADATA" "$GENERAL_PAGE" "$TARGET_MO" "$OVERLAY" "$BACKUP_MO"
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
check_sha "$BACKUP_MO" "$EXPECTED_UPSTREAM_MO_SHA" "pristine Polish catalog backup"

python3 - "$METADATA" "$DOMAIN" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

if data.get("gettext-domain") != sys.argv[2]:
    raise SystemExit("FAIL: unexpected AppIndicator gettext-domain")
PY

msgfmt --check --check-format "$OVERLAY" -o /dev/null

entries="$(grep -c '^msgid "' "$OVERLAY")"
entries=$((entries - 1))

[[ "$entries" -eq "$EXPECTED_COMPLETION_ENTRIES" ]] || {
    echo "FAIL: expected $EXPECTED_COMPLETION_ENTRIES AppIndicator entries, found $entries" >&2
    exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

msgfmt "$OVERLAY" -o "$tmp/overlay.mo"
msgunfmt "$BACKUP_MO" -o "$tmp/upstream.po"

msgcat --use-first \
    "$OVERLAY" \
    "$tmp/upstream.po" \
    -o "$tmp/merged.po"

msgfmt --check --check-format \
    "$tmp/merged.po" \
    -o "$tmp/expected.mo"

cmp -s "$tmp/expected.mo" "$TARGET_MO" || {
    echo "FAIL: live AppIndicator Polish catalog differs from repository reconstruction" >&2
    exit 1
}

untranslated="$(
    msgattrib --untranslated --no-obsolete "$tmp/merged.po" \
      | grep -c '^msgid ' || true
)"

fuzzy="$(
    msgattrib --only-fuzzy --no-obsolete "$tmp/merged.po" \
      | grep -c '^msgid ' || true
)"

[[ "$untranslated" -eq 0 && "$fuzzy" -eq 0 ]] || {
    echo "FAIL: merged AppIndicator catalog incomplete: untranslated=$untranslated fuzzy=$fuzzy" >&2
    exit 1
}

python3 - \
    "$BACKUP_MO" \
    "$TARGET_MO" <<'PY'
import gettext
import sys

upstream_path, installed_path = sys.argv[1:]

expected = {
    "General": "Ogólne",
    "Add X11 legacy tray icons to the panel area":
        "Dodaj starsze ikony zasobnika X11 do panelu",
    "Compact Mode": "Tryb kompaktowy",
    "Puts tray indicators closer together":
        "Umieszcza wskaźniki zasobnika bliżej siebie",
    "Desaturation": "Zmniejszenie nasycenia",
    "Icon Size": "Rozmiar ikon",
    "Tray Horizontal Alignment":
        "Poziome wyrównanie zasobnika",
}

with open(upstream_path, "rb") as f:
    upstream = gettext.GNUTranslations(f)

with open(installed_path, "rb") as f:
    installed = gettext.GNUTranslations(f)

for source, translated in expected.items():
    upstream_value = upstream.gettext(source)

    if upstream_value != source:
        raise SystemExit(
            f"FAIL: expected audited upstream gap for {source!r}, "
            f"got {upstream_value!r}"
        )

    actual = installed.gettext(source)

    if actual != translated:
        raise SystemExit(
            f"FAIL: {source!r}: expected {translated!r}, got {actual!r}"
        )

print(f"AppIndicator gettext checks: {len(expected)}")
PY

echo "PASS: AppIndicator v64 / Fedora 44 Polish localization matches repository completion ($EXPECTED_COMPLETION_ENTRIES entries, 0 fuzzy)"
