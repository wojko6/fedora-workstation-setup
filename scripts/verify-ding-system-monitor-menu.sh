#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="ding@rastersoft.com"
MANIFEST="$ROOT_DIR/gnome/managed-system-extensions.tsv"
TREE_HELPER="$ROOT_DIR/scripts/extension_tree_integrity.py"
DESKTOP_FILE="/usr/share/applications/org.gnome.SystemMonitor.desktop"
USER_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
UPDATE_DIR="$HOME/.local/share/gnome-shell/extension-updates/$UUID"

command -v restorecon >/dev/null 2>&1 || {
    echo "FAIL: restorecon is required for DING SELinux label verification" >&2
    exit 1
}

data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
case ":$data_dirs:" in
    *:/usr/local/share:*) ;;
    *)
        echo "FAIL: /usr/local/share is not present in XDG_DATA_DIRS: $data_dirs" >&2
        exit 1
        ;;
esac

for path in "$MANIFEST" "$TREE_HELPER" "$DESKTOP_FILE"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required DING managed-system verification file missing: $path" >&2
        exit 1
    }
done

readarray -t row < <(
    python3 - "$MANIFEST" "$UUID" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
uuid = sys.argv[2]

with path.open(encoding="utf-8", newline="") as fh:
    rows = [r for r in csv.DictReader(fh, delimiter="\t") if r.get("uuid") == uuid]

if len(rows) != 1:
    raise SystemExit(f"expected exactly one managed-system row for {uuid}, found {len(rows)}")

r = rows[0]
for key in ("runtime_version", "shell_major", "managed_tree_sha256", "location"):
    value = (r.get(key) or "").strip()
    if not value:
        raise SystemExit(f"missing {key} for {uuid}")
    print(value)
PY
)

[[ "${#row[@]}" -eq 4 ]] || {
    echo "FAIL: managed-system manifest parse failed" >&2
    exit 1
}

EXPECTED_VERSION="${row[0]}"
SHELL_MAJOR="${row[1]}"
EXPECTED_TREE_SHA256="${row[2]}"
EXT_DIR="${row[3]}"
TARGET="$EXT_DIR/app/desktopMenu.js"
DING_MO="$EXT_DIR/locale/pl/LC_MESSAGES/ding.mo"

for path in "$EXT_DIR/metadata.json" "$TARGET" "$DING_MO"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required managed DING file missing: $path" >&2
        exit 1
    }
done

[[ ! -e "$USER_DIR" ]] || {
    echo "FAIL: per-user DING copy still exists: $USER_DIR" >&2
    exit 1
}

[[ ! -e "$UPDATE_DIR" ]] || {
    echo "FAIL: pending per-user DING update still exists: $UPDATE_DIR" >&2
    exit 1
}

owner="$(stat -c '%U:%G' "$EXT_DIR")"
[[ "$owner" == "root:root" ]] || {
    echo "FAIL: managed DING directory must be root:root, found $owner" >&2
    exit 1
}

if find "$EXT_DIR" \( ! -user root -o ! -group root \) -print -quit | grep -q .; then
    echo "FAIL: managed DING tree contains non-root-owned entries" >&2
    exit 1
fi

label_drift="$(restorecon -nRFv "$EXT_DIR" 2>/dev/null || true)"
[[ -z "$label_drift" ]] || {
    printf '%s\n' "$label_drift" >&2
    echo "FAIL: managed DING tree has SELinux label drift" >&2
    exit 1
}

python3 - "$EXT_DIR/metadata.json" "$UUID" "$EXPECTED_VERSION" "$SHELL_MAJOR" <<'PY'
import json
import sys
from pathlib import Path

path, uuid, version, shell_major = sys.argv[1:5]
data = json.loads(Path(path).read_text(encoding="utf-8"))

if data.get("uuid") != uuid:
    raise SystemExit(f"FAIL: DING UUID mismatch: {data.get('uuid')!r}")
if str(data.get("version")) != version:
    raise SystemExit(
        f"FAIL: DING runtime version drift: expected {version}, found {data.get('version')!r}"
    )
if shell_major not in [str(v) for v in data.get("shell-version", [])]:
    raise SystemExit(f"FAIL: DING does not declare GNOME Shell {shell_major}")
if data.get("name") != "Ikony pulpitu NG (DING)":
    raise SystemExit(
        f"FAIL: DING managed Polish display name drift: {data.get('name')!r}"
    )
PY

actual_tree_sha="$(python3 "$TREE_HELPER" hash --path "$EXT_DIR")"
[[ "$actual_tree_sha" == "$EXPECTED_TREE_SHA256" ]] || {
    echo "FAIL: DING managed tree integrity drift: expected $EXPECTED_TREE_SHA256, found $actual_tree_sha" >&2
    exit 1
}

python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required = [
    "this._addNewAction('open-system-monitor', null, () => {",
    "GioUnix.DesktopAppInfo.new('org.gnome.SystemMonitor.desktop')",
    "this._newMenuElement(_('System Monitor'), 'open-system-monitor', section);",
]

for token in required:
    if text.count(token) != 1:
        raise SystemExit(
            f"FAIL: DING System Monitor integration token count is not exactly one: {token}"
        )
PY

python3 - "$DING_MO" <<'PY'
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
            f"FAIL: DING Polish runtime label drift for {msgid!r}: "
            f"expected {msgstr!r}, found {actual!r}"
        )
PY

if gnome-extensions info "$UUID" >/dev/null 2>&1; then
    runtime_path="$(
        gnome-extensions info "$UUID" 2>/dev/null |
        sed -nE 's/^[[:space:]]*(Path|Ścieżka):[[:space:]]*//p' |
        head -n 1
    )"

    [[ "$runtime_path" == "$EXT_DIR" ]] || {
        echo "FAIL: GNOME runtime still resolves DING from ${runtime_path:-unknown}; sign out/in after migration" >&2
        exit 1
    }
fi

echo "PASS: DING v99 managed-system tree = $actual_tree_sha"
echo "PASS: DING system scope, root ownership and SELinux labels are correct"
echo "PASS: DING per-user copy and pending update are absent"
echo "PASS: DING Polish desktop menu and System Monitor integration match repository"
