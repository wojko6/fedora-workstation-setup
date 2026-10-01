#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

UUID="ding@rastersoft.com"
VERSION="99"
SHELL_MAJOR="50"
ARCHIVE_SHA256="f5f80d3371f00b7f3fd073d33c90f1c18750f006a284e76f37c1973685a33acc"
PRISTINE_METADATA_SHA256="b9c65a2b4d8f17eb6c1f8bb2ef3c109dc2224ee428ac9b6338aa0d13075b23aa"
PRISTINE_MENU_SHA256="7bec5bccf631f1ed50a7f20c0892074718f22f260f243d4c9122d86aa1c5815f"
PRISTINE_PL_MO_SHA256="5b11620428bb71f65c2fbd8af8bc0c0aca6f312640728f94af05f62fe4b1f066"

ARCHIVE_URL="https://extensions.gnome.org/extension-data/dingrastersoft.com.v99.shell-extension.zip"
PO="$ROOT_DIR/localization/ding/pl.po"
PATCH_FILE="$ROOT_DIR/patches/gnome-extensions/ding/v99-desktopMenu-system-monitor.patch"
EGO_VERIFIER="$ROOT_DIR/scripts/verify_ego_extension.py"
TREE_HELPER="$ROOT_DIR/scripts/extension_tree_integrity.py"

OUTPUT=""

usage() {
    cat <<'EOF'
Usage:
  build-ding-v99-managed-tree.sh --output DIR

Builds the accepted DING v99 managed tree without touching the live extension.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --output)
            [[ $# -ge 2 ]] || { echo "ERROR: --output requires a directory" >&2; exit 2; }
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ -n "$OUTPUT" ]] || {
    echo "ERROR: --output is required" >&2
    exit 2
}

for cmd in curl unzip sha256sum python3 msgfmt patch glib-compile-schemas install; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: required command missing: $cmd" >&2
        exit 1
    }
done

for path in "$PO" "$PATCH_FILE" "$EGO_VERIFIER" "$TREE_HELPER"; do
    [[ -f "$path" ]] || {
        echo "ERROR: required repository file missing: $path" >&2
        exit 1
    }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVE="$TMP/ding-v99.zip"
STAGE="$TMP/stage"
PATCH_LOG="$TMP/patch.log"
COMPILED_MO="$TMP/ding.mo"

echo "=== DING V99 MANAGED-TREE BUILDER ==="
echo "Live extension is not modified by this script."

echo
echo "=== DOWNLOAD / SOURCE VERIFICATION ==="
curl -fL --retry 2 -o "$ARCHIVE" "$ARCHIVE_URL"

python3 "$EGO_VERIFIER" \
    --archive "$ARCHIVE" \
    --sha256 "$ARCHIVE_SHA256" \
    --uuid "$UUID" \
    --version "$VERSION" \
    --shell-major "$SHELL_MAJOR"

mkdir -p "$STAGE"
unzip -q "$ARCHIVE" -d "$STAGE"

metadata_sha="$(sha256sum "$STAGE/metadata.json" | awk '{print $1}')"
menu_sha="$(sha256sum "$STAGE/app/desktopMenu.js" | awk '{print $1}')"
pl_mo_sha="$(sha256sum "$STAGE/locale/pl/LC_MESSAGES/ding.mo" | awk '{print $1}')"

[[ "$metadata_sha" == "$PRISTINE_METADATA_SHA256" ]] || {
    echo "ERROR: pristine v99 metadata fingerprint drift: $metadata_sha" >&2
    exit 1
}

[[ "$menu_sha" == "$PRISTINE_MENU_SHA256" ]] || {
    echo "ERROR: pristine v99 desktopMenu.js fingerprint drift: $menu_sha" >&2
    exit 1
}

[[ "$pl_mo_sha" == "$PRISTINE_PL_MO_SHA256" ]] || {
    echo "ERROR: pristine v99 Polish catalog fingerprint drift: $pl_mo_sha" >&2
    exit 1
}

echo "PASS: pristine v99 critical fingerprints match physical audit"

echo
echo "=== POLISH CATALOG ==="
msgfmt --check "$PO" -o "$COMPILED_MO"
install -m 0644 "$COMPILED_MO" "$STAGE/locale/pl/LC_MESSAGES/ding.mo"

python3 - "$STAGE/locale/pl/LC_MESSAGES/ding.mo" <<'PY'
import gettext
import sys

expected = {
    "Arrange Icons": "Rozmieść ikony",
    "Arrange By...": "Sortuj według...",
    "Show Desktop in Files": "Wyświetl pulpit w menedżerze plików",
    "Change Background…": "Zmień tło…",
    "Desktop Icons Settings": "Ustawienia ikon pulpitu",
    "Display Settings": "Ustawienia ekranu",
    "Keep Arranged...": "Autorozmieszczanie",
    "Keep Stacked by type...": "Grupowanie według typu...",
    "Sort Home/Drives/Trash...": "Sortuj katalog domowy/dyski/kosz...",
    "System Monitor": "Monitor systemu",
}

with open(sys.argv[1], "rb") as fh:
    tr = gettext.GNUTranslations(fh)

for msgid, msgstr in expected.items():
    actual = tr.gettext(msgid)
    if actual != msgstr:
        raise SystemExit(
            f"ERROR: Polish DING catalog mismatch for {msgid!r}: "
            f"expected {msgstr!r}, found {actual!r}"
        )

print(f"PASS: Polish DING menu coverage = {len(expected)}/{len(expected)}")
PY

echo
echo "=== SYSTEM MONITOR PATCH ==="
if ! patch \
    --batch \
    --forward \
    --fuzz=0 \
    -p1 \
    -d "$STAGE" \
    < "$PATCH_FILE" >"$PATCH_LOG" 2>&1; then
    cat "$PATCH_LOG" >&2
    echo "ERROR: exact DING v99 System Monitor patch failed" >&2
    exit 1
fi

cat "$PATCH_LOG"

if grep -Eqi 'offset|fuzz' "$PATCH_LOG"; then
    echo "ERROR: DING v99 patch unexpectedly required offset/fuzz" >&2
    exit 1
fi

python3 - "$STAGE/app/desktopMenu.js" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required = [
    "this._addNewAction('open-system-monitor'",
    "org.gnome.SystemMonitor.desktop",
    "this._newMenuElement(_('System Monitor'), 'open-system-monitor', section);",
]

for token in required:
    if text.count(token) != 1:
        raise SystemExit(
            f"ERROR: managed desktopMenu.js token count is not exactly one: {token}"
        )

print("PASS: System Monitor action/menu integration is exact")
PY

echo
echo "=== POLISH DISPLAY NAME ==="
python3 - "$STAGE/metadata.json" "$PRISTINE_METADATA_SHA256" <<'PY'
from pathlib import Path
import hashlib
import json
import re
import sys

path = Path(sys.argv[1])
expected_sha = sys.argv[2]
raw = path.read_bytes()

if hashlib.sha256(raw).hexdigest() != expected_sha:
    raise SystemExit("ERROR: metadata changed before display-name localization")

data = json.loads(raw.decode("utf-8"))
if data.get("version") != 99:
    raise SystemExit(f"ERROR: unexpected DING version: {data.get('version')!r}")
if data.get("name") != "Desktop Icons NG (DING)":
    raise SystemExit(f"ERROR: unexpected pristine DING name: {data.get('name')!r}")

old = json.dumps("Desktop Icons NG (DING)", ensure_ascii=False).encode()
new = json.dumps("Ikony pulpitu NG (DING)", ensure_ascii=False).encode()
pattern = re.compile(rb'("name"\s*:\s*)' + re.escape(old))

if len(pattern.findall(raw)) != 1:
    raise SystemExit("ERROR: DING metadata name replacement is not unique")

path.write_bytes(pattern.sub(lambda m: m.group(1) + new, raw, count=1))
print("PASS: DING Polish display name prepared")
PY

echo
echo "=== SCHEMAS ==="
if compgen -G "$STAGE/schemas/*.gschema.xml" >/dev/null; then
    glib-compile-schemas --strict "$STAGE/schemas"
    [[ -f "$STAGE/schemas/gschemas.compiled" ]] || {
        echo "ERROR: DING schema compilation did not produce gschemas.compiled" >&2
        exit 1
    }
    echo "PASS: DING schemas compiled"
else
    echo "INFO: DING archive has no local schema XML"
fi

echo
echo "=== SYSTEM-SCOPE PERMISSIONS ==="
chmod -R u=rwX,go=rX "$STAGE"

if find "$STAGE" -type f ! -perm -004 -print -quit | grep -q .; then
    echo "ERROR: managed DING tree contains a file that is not world-readable" >&2
    exit 1
fi

if find "$STAGE" -type d ! -perm -005 -print -quit | grep -q .; then
    echo "ERROR: managed DING tree contains a directory that is not world-readable/executable" >&2
    exit 1
fi

echo "PASS: managed DING permissions normalized for system scope"

echo
echo "=== FINAL METADATA ==="
python3 - "$STAGE/metadata.json" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(f"uuid={data.get('uuid')!r}")
print(f"name={data.get('name')!r}")
print(f"version={data.get('version')!r}")
print(f"shell-version={data.get('shell-version')!r}")

if data.get("uuid") != "ding@rastersoft.com":
    raise SystemExit("ERROR: final DING UUID mismatch")
if data.get("name") != "Ikony pulpitu NG (DING)":
    raise SystemExit("ERROR: final DING display name mismatch")
if data.get("version") != 99:
    raise SystemExit("ERROR: final DING runtime version mismatch")
if "50" not in [str(v) for v in data.get("shell-version", [])]:
    raise SystemExit("ERROR: final DING GNOME 50 compatibility missing")
PY

rm -rf "$OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"
mv "$STAGE" "$OUTPUT"

tree_sha="$(python3 "$TREE_HELPER" hash --path "$OUTPUT")"

echo
echo "=== MANAGED TREE RESULT ==="
echo "MANAGED_TREE_SHA256=$tree_sha"
echo "OUTPUT=$OUTPUT"
echo "NO_LIVE_MUTATION=YES"
