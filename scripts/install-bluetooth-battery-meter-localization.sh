#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="Bluetooth-Battery-Meter@maniacx.github.com"
DOMAIN="$UUID"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
BUDSLINK_JS="$EXT_DIR/preferences/budslinkCompanion.js"
BUDSLINK_UI="$EXT_DIR/ui/budslinkCompanion.ui"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.pre-budslink-v46.bak"
OVERLAY="$ROOT_DIR/localization/bluetooth-battery-meter/v46-budslink-completion.po"
VERIFIER="$ROOT_DIR/scripts/verify-bluetooth-battery-meter-localization.sh"

EXPECTED_VERSION="46"
EXPECTED_DOMAIN="$DOMAIN"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Bluetooth Battery Meter extension not installed"
    exit 0
fi

for cmd in python3 msgfmt msgcat msgunfmt install cp cmp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

for path in "$METADATA" "$BUDSLINK_JS" "$BUDSLINK_UI" "$OVERLAY" "$TARGET_MO" "$VERIFIER"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Bluetooth Battery Meter localization file missing: $path" >&2
        exit 1
    fi
done

readarray -t metadata_values < <(python3 - "$METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('version', ''))
print(data.get('gettext-domain', ''))
PY
)

version="${metadata_values[0]:-}"
domain="${metadata_values[1]:-}"

if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Bluetooth Battery Meter version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    exit 1
fi

if [[ "$domain" != "$EXPECTED_DOMAIN" ]]; then
    echo "FAIL: Bluetooth Battery Meter gettext domain drift: expected $EXPECTED_DOMAIN, found ${domain:-unknown}" >&2
    exit 1
fi

python3 - "$BUDSLINK_JS" "$BUDSLINK_UI" "$EXPECTED_DOMAIN" <<'PY'
import sys
from pathlib import Path

js_path, ui_path, domain = sys.argv[1:]
js = Path(js_path).read_text(encoding='utf-8')
ui = Path(ui_path).read_text(encoding='utf-8')

js_messages = (
    'Install BudsLink from Flathub to monitor battery levels for multiple devices and access advanced controls such as noise control, equalizer, and gestures, when supported by the device',
    'Currently supported earbuds and headbands are:',
    'Installed',
    'Update Extension',
    'Update BudsLink',
    'Not Installed',
    'Refresh',
)
ui_messages = (
    'BudsLink Companion',
    'Enable BudsLink integration',
    'Acts as a Companion with the BudsLink app, which runs in the background to provide additional features for supported headphones and earbuds',
    'Hide from Background Apps',
    'Hide BudsLink from the GNOME Background Apps list',
    'Installation Status',
    'BudsLink Installation Status',
    'BudsLink on Flathub',
    'BudsLink Documentation',
)

missing = [message for message in js_messages if message not in js]
missing += [message for message in ui_messages if message not in ui]
if f'domain="{domain}"' not in ui:
    missing.append(f'UI gettext domain {domain}')
if missing:
    for item in missing:
        print(f'FAIL: Bluetooth Battery Meter v46 BudsLink source message missing: {item}', file=sys.stderr)
    raise SystemExit(1)
PY

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

msgfmt --check "$OVERLAY" -o "$tmpdir/overlay.mo"

python3 - "$tmpdir/overlay.mo" <<'PY'
import gettext
import sys

expected = {
    'Install BudsLink from Flathub to monitor battery levels for multiple devices and access advanced controls such as noise control, equalizer, and gestures, when supported by the device': 'Zainstaluj BudsLink z Flathuba, aby monitorować poziom naładowania baterii wielu urządzeń i korzystać z zaawansowanych funkcji, takich jak sterowanie redukcją hałasu, korektor dźwięku i gesty — jeśli urządzenie je obsługuje',
    'Currently supported earbuds and headbands are:': 'Obecnie obsługiwane słuchawki douszne i nauszne:',
    'Installed': 'Zainstalowano',
    'Update Extension': 'Zaktualizuj rozszerzenie',
    'Update BudsLink': 'Zaktualizuj BudsLink',
    'Not Installed': 'Nie zainstalowano',
    'Refresh': 'Odśwież',
    'BudsLink Companion': 'BudsLink Companion',
    'Enable BudsLink integration': 'Włącz integrację z BudsLink',
    'Acts as a Companion with the BudsLink app, which runs in the background to provide additional features for supported headphones and earbuds': 'Współpracuje z działającą w tle aplikacją BudsLink, aby udostępniać dodatkowe funkcje obsługiwanych słuchawek dousznych i nausznych',
    'Hide from Background Apps': 'Ukryj na liście aplikacji działających w tle',
    'Hide BudsLink from the GNOME Background Apps list': 'Ukryj BudsLink na liście aplikacji GNOME działających w tle',
    'Installation Status': 'Stan instalacji',
    'BudsLink Installation Status': 'Stan instalacji BudsLink',
    'BudsLink on Flathub': 'BudsLink we Flathubie',
    'BudsLink Documentation': 'Dokumentacja BudsLink',
}
with open(sys.argv[1], 'rb') as fh:
    catalog = gettext.GNUTranslations(fh)
for source, translated in expected.items():
    actual = catalog.gettext(source)
    if actual != translated:
        print(f'FAIL: completion overlay mismatch for {source!r}: {actual!r}', file=sys.stderr)
        raise SystemExit(1)
PY

if [[ ! -f "$BACKUP_MO" ]]; then
    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
fi

if ! msgunfmt "$BACKUP_MO" -o "$tmpdir/base.po"; then
    echo "FAIL: saved Bluetooth Battery Meter Polish catalog is invalid: $BACKUP_MO" >&2
    exit 1
fi

msgcat --use-first "$OVERLAY" "$tmpdir/base.po" -o "$tmpdir/merged.po"
msgfmt --check "$tmpdir/merged.po" -o "$tmpdir/$DOMAIN.mo"
install -m 0644 "$tmpdir/$DOMAIN.mo" "$TARGET_MO"

bash "$VERIFIER"
echo "PASS: Bluetooth Battery Meter v46 BudsLink Polish completion installed"
echo "Close and reopen the extension preferences to reload the translated BudsLink page."
