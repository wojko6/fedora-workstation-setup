#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="just-perfection-desktop@just-perfection"
DOMAIN="just-perfection"
EXPECTED_VERSION="37"
BASE_PO="$ROOT_DIR/localization/just-perfection/pl.po"
ADDITIONS_PO="$ROOT_DIR/localization/just-perfection/v37-additions.po"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "SKIP: Just Perfection is not installed: $UUID"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "FAIL: python3 unavailable" >&2; exit 1; }
command -v msgfmt >/dev/null 2>&1 || { echo "FAIL: msgfmt unavailable" >&2; exit 1; }
command -v msgcat >/dev/null 2>&1 || { echo "FAIL: msgcat unavailable" >&2; exit 1; }

[[ -f "$METADATA" ]] || { echo "FAIL: missing metadata: $METADATA" >&2; exit 1; }
[[ -f "$BASE_PO" ]] || { echo "FAIL: missing translation source: $BASE_PO" >&2; exit 1; }
[[ -f "$ADDITIONS_PO" ]] || { echo "FAIL: missing v37 completion source: $ADDITIONS_PO" >&2; exit 1; }
[[ -f "$TARGET_MO" ]] || { echo "FAIL: missing installed Polish catalog: $TARGET_MO" >&2; exit 1; }

read -r version domain < <(
  python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("version", ""), data.get("gettext-domain", ""))
PY
)

[[ "$version" == "$EXPECTED_VERSION" ]] || {
  echo "FAIL: Just Perfection version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
  exit 1
}
[[ "$domain" == "$DOMAIN" ]] || {
  echo "FAIL: Just Perfection gettext-domain drift: expected $DOMAIN, found ${domain:-missing}" >&2
  exit 1
}

msgfmt --check "$BASE_PO" -o /dev/null
msgfmt --check "$ADDITIONS_PO" -o /dev/null

tmp_po="$(mktemp)"
tmp_mo="$(mktemp)"
trap 'rm -f "$tmp_po" "$tmp_mo"' EXIT
msgcat --use-first "$BASE_PO" "$ADDITIONS_PO" -o "$tmp_po"
msgfmt --check "$tmp_po" -o "$tmp_mo"

python3 - "$tmp_po" <<'PY'
import ast
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
entries = []
current = {"msgid": None, "msgstr": None}
field = None

def decode(token: str) -> str:
    return ast.literal_eval(token.strip())

def flush():
    global current
    if current["msgid"] is not None:
        entries.append(current)
    current = {"msgid": None, "msgstr": None}

for line in lines + [""]:
    if line.startswith("msgid "):
        if current["msgid"] is not None:
            flush()
        current["msgid"] = decode(line[6:])
        current["msgstr"] = ""
        field = "msgid"
    elif line.startswith("msgstr "):
        current["msgstr"] = decode(line[7:])
        field = "msgstr"
    elif line.startswith('"') and field:
        current[field] += decode(line)
    elif not line.strip():
        if current["msgid"] is not None:
            flush()
        field = None

catalog = {e["msgid"]: e["msgstr"] for e in entries if e["msgid"]}
missing = [msgid for msgid, msgstr in catalog.items() if not msgstr]
if missing:
    for msgid in missing:
        print(f"FAIL: untranslated msgid: {msgid}", file=sys.stderr)
    raise SystemExit(1)

required_v37_delta = {
    "Changelog",
    "Backlight Toggle Button",
    "Backlight Toggle Button in Quick settings menu",
    "Do Not Disturb Toggle Button",
    "Do Not Disturb Button in Quick setttings menu",
    "Window Menu",
    "Window menu when you right click in title bar",
}
absent = sorted(required_v37_delta - set(catalog))
if absent:
    for msgid in absent:
        print(f"FAIL: missing audited v37 msgid: {msgid}", file=sys.stderr)
    raise SystemExit(1)

print(f"Translated entries: {len(catalog)}")
print("PASS: audited v35-v37 Just Perfection UI additions are covered")
PY

cmp -s "$tmp_mo" "$TARGET_MO" || {
  echo "FAIL: installed Just Perfection Polish catalog differs from repository" >&2
  exit 1
}

echo "PASS: Just Perfection v37 Polish localization matches repository"
