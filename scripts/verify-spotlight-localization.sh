#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="spotlight@nin"
DOMAIN="spotlight"
EXPECTED_VERSION="14"
EXPECTED_VERSION_NAME="2026.11"
EXPECTED_TRANSLATED="22"
SOURCE_PO="$ROOT_DIR/localization/spotlight/pl.po"
PATCH_DIR="$ROOT_DIR/patches/gnome-extensions/spotlight"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_DIR="$EXT_DIR/.localization-backup-v14-2026.11"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "SKIP: Spotlight is not installed: $UUID"
  exit 0
fi

for cmd in python3 msgfmt patch; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "FAIL: required command unavailable: $cmd" >&2
    exit 1
  }
done

[[ -f "$METADATA" ]] || { echo "FAIL: missing Spotlight metadata" >&2; exit 1; }
[[ -f "$SOURCE_PO" ]] || { echo "FAIL: missing Spotlight Polish source catalog" >&2; exit 1; }
[[ -f "$TARGET_MO" ]] || { echo "FAIL: missing installed Spotlight Polish catalog" >&2; exit 1; }
[[ -d "$BACKUP_DIR" ]] || { echo "FAIL: missing Spotlight pristine localization backup" >&2; exit 1; }

read -r version version_name domain < <(
  python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("version", ""), data.get("version-name", ""), data.get("gettext-domain", ""))
PY
)

[[ "$version" == "$EXPECTED_VERSION" ]] || {
  echo "FAIL: Spotlight numeric version drift: expected $EXPECTED_VERSION, found ${version:-?}" >&2
  exit 1
}
[[ "$version_name" == "$EXPECTED_VERSION_NAME" ]] || {
  echo "FAIL: Spotlight version-name drift: expected $EXPECTED_VERSION_NAME, found ${version_name:-?}" >&2
  exit 1
}
[[ "$domain" == "$DOMAIN" ]] || {
  echo "FAIL: Spotlight gettext-domain drift: expected $DOMAIN, found ${domain:-missing}" >&2
  exit 1
}

read -r backup_version backup_version_name < <(
  python3 - "$BACKUP_DIR/metadata.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("version", ""), data.get("version-name", ""))
PY
)
[[ "$backup_version" == "$EXPECTED_VERSION" && "$backup_version_name" == "$EXPECTED_VERSION_NAME" ]] || {
  echo "FAIL: Spotlight pristine backup does not match v14 / 2026.11" >&2
  exit 1
}

msgfmt --check "$SOURCE_PO" -o /dev/null
translated="$({ python3 - "$SOURCE_PO" <<'PY'
import ast
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
entries = []
current = {"msgid": None, "msgstr": None}
field = None

def decode(token):
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

missing = [e["msgid"] for e in entries if e["msgid"] and not e["msgstr"]]
if missing:
    for msgid in missing:
        print(f"FAIL: untranslated Spotlight msgid: {msgid}", file=sys.stderr)
    raise SystemExit(1)
print(sum(1 for e in entries if e["msgid"]))
PY
} )"

[[ "$translated" == "$EXPECTED_TRANSLATED" ]] || {
  echo "FAIL: expected $EXPECTED_TRANSLATED translated Spotlight strings, found $translated" >&2
  exit 1
}

files=(
  metadata.json
  prefs.js
  prefs/shortcutPage.js
  prefs/appearancePage.js
  prefs/aboutPage.js
)
for rel in "${files[@]}"; do
  [[ -f "$BACKUP_DIR/$rel" ]] || { echo "FAIL: Spotlight backup source missing: $rel" >&2; exit 1; }
  [[ -f "$EXT_DIR/$rel" ]] || { echo "FAIL: Spotlight live source missing: $rel" >&2; exit 1; }
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/prefs"
for rel in "${files[@]}"; do
  cp -a "$BACKUP_DIR/$rel" "$tmp_dir/$rel"
done

patch_count=0
while IFS= read -r patch_file; do
  patch_count=$((patch_count + 1))
  patch --batch --forward -p1 -d "$tmp_dir" < "$patch_file" >/dev/null
done < <(find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | sort)
[[ "$patch_count" -eq 4 ]] || {
  echo "FAIL: expected 4 Spotlight patches, found $patch_count" >&2
  exit 1
}

python3 - "$tmp_dir/metadata.json" "$DOMAIN" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["gettext-domain"] = sys.argv[2]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

for rel in "${files[@]}"; do
  cmp -s "$tmp_dir/$rel" "$EXT_DIR/$rel" || {
    echo "FAIL: Spotlight localized source differs from repository patch set: $rel" >&2
    exit 1
  }
done

msgfmt "$SOURCE_PO" -o "$tmp_dir/$DOMAIN.mo"
cmp -s "$tmp_dir/$DOMAIN.mo" "$TARGET_MO" || {
  echo "FAIL: installed Spotlight Polish catalog differs from repository" >&2
  exit 1
}

echo "Translated entries: $translated"
echo "PASS: Spotlight v14 / 2026.11 Polish localization matches repository"
