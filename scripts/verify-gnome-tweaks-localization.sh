#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGE="gnome-tweaks"
EXPECTED_NEVRA="gnome-tweaks-49.0-2.fc44.noarch"
EXPECTED_WIDGETS_SHA="2d1cba580bbfe37fd06244c76895f81c4358c2a2e2ece8c27a81cf0302d1ddca"
EXPECTED_MO_SHA="b6b9ec6189ff735a635cbc31aa6a709291a90ee73046970a185f136855209b65"
EXPECTED_OVERLAY_ENTRIES=11

WIDGETS="/usr/lib/python3.14/site-packages/gtweak/widgets.py"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/gnome-tweaks.mo"
OVERLAY="$ROOT_DIR/localization/gnome-tweaks/v49.0-gsettings-enums.po"
PATCH_FILE="$ROOT_DIR/patches/gnome-tweaks/v49.0-gsettings-enum-gettext.patch"

STATE_DIR="/var/lib/fedora-workstation-setup/gnome-tweaks/49.0-2.fc44"
BACKUP_WIDGETS="$STATE_DIR/widgets.py.upstream"
BACKUP_MO="$STATE_DIR/gnome-tweaks.mo.upstream"

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: GNOME Tweaks is not installed"
    exit 0
fi

for cmd in rpm sha256sum msgfmt msgcat msgunfmt msgattrib gettext patch cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

nevra="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$PACKAGE")"
if [[ "$nevra" != "$EXPECTED_NEVRA" ]]; then
    echo "FAIL: GNOME Tweaks package drift: expected $EXPECTED_NEVRA, found ${nevra:-unknown}" >&2
    exit 1
fi

for path in "$WIDGETS" "$TARGET_MO" "$OVERLAY" "$PATCH_FILE" "$BACKUP_WIDGETS" "$BACKUP_MO"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required GNOME Tweaks localization file missing: $path" >&2
        exit 1
    fi
done

check_sha() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: GNOME Tweaks $label fingerprint differs: $actual" >&2
        exit 1
    fi
}

check_sha "$BACKUP_WIDGETS" "$EXPECTED_WIDGETS_SHA" "pristine widgets.py backup"
check_sha "$BACKUP_MO" "$EXPECTED_MO_SHA" "pristine Polish catalog backup"

msgfmt --check "$OVERLAY" -o /dev/null

overlay_entries="$(grep -c '^msgid "' "$OVERLAY")"
overlay_entries=$((overlay_entries - 1))
if [[ "$overlay_entries" -ne "$EXPECTED_OVERLAY_ENTRIES" ]]; then
    echo "FAIL: GNOME Tweaks overlay entry count: expected $EXPECTED_OVERLAY_ENTRIES, found $overlay_entries" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/gtweak"
cp -a "$BACKUP_WIDGETS" "$tmpdir/gtweak/widgets.py"

patch --batch --forward -p1 -d "$tmpdir" <"$PATCH_FILE" >/dev/null

if ! cmp -s "$tmpdir/gtweak/widgets.py" "$WIDGETS"; then
    echo "FAIL: live GNOME Tweaks widgets.py differs from repository patch" >&2
    exit 1
fi

msgunfmt "$BACKUP_MO" -o "$tmpdir/upstream.po"
msgcat --use-first "$OVERLAY" "$tmpdir/upstream.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/gnome-tweaks.mo"

if ! cmp -s "$tmpdir/gnome-tweaks.mo" "$TARGET_MO"; then
    echo "FAIL: live GNOME Tweaks Polish catalog differs from repository completion" >&2
    exit 1
fi

untranslated="$(msgattrib --untranslated --no-obsolete "$tmpdir/merged.po" | grep -c '^msgid ' || true)"
fuzzy="$(msgattrib --only-fuzzy --no-obsolete "$tmpdir/merged.po" | grep -c '^msgid ' || true)"

if [[ "$untranslated" -ne 0 || "$fuzzy" -ne 0 ]]; then
    echo "FAIL: merged GNOME Tweaks Polish catalog has untranslated/fuzzy entries (untranslated=$untranslated fuzzy=$fuzzy)" >&2
    exit 1
fi

while IFS='|' read -r source expected; do
    actual="$(
        LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8             gettext -d gnome-tweaks "$source"
    )"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: GNOME Tweaks gettext for '$source': expected '$expected', found '$actual'" >&2
        exit 1
    fi
done <<'EOF'
None|Brak
Toggle Shade|Przełącz zwinięcie
Toggle Maximize|Przełącz maksymalizację
Toggle Maximize Horizontally|Przełącz maksymalizację w poziomie
Toggle Maximize Vertically|Przełącz maksymalizację w pionie
Minimize|Minimalizacja
Lower|Przenieś na spód
Menu|Menu
Wallpaper|Tapeta
Centered|Wyśrodkowane
Scaled|Skalowane
Stretched|Rozciągnięte
Zoom|Powiększenie
Spanned|Rozciągnięte na wiele ekranów
EOF

if ! grep -Fq 'title=_(v.replace("-", " ").title())' "$WIDGETS"; then
    echo "FAIL: GNOME Tweaks generated GSettings labels are not passed through gettext" >&2
    exit 1
fi

echo "PASS: GNOME Tweaks 49.0 generated GSettings labels use gettext"
echo "PASS: GNOME Tweaks 49.0 Polish localization matches repository completion ($EXPECTED_OVERLAY_ENTRIES added entries)"
