#!/usr/bin/env bash
set -Eeuo pipefail

COMMIT="99247ecd219bdc1c7409baff062b4aafcf1102a7"

UPSTREAM_BASE="https://raw.githubusercontent.com/vinceliuice/WhiteSur-gtk-theme/${COMMIT}/other/gnome-theme-switcher"

EXPECTED_SCRIPT_SHA256="98f939dd770d9b5ba594fc5e24e7bb9562c2e2ee74d554f7b6dde367dd4b00e4"
EXPECTED_DESKTOP_SHA256="31afd0e3fe74c9716f270008f77f16e5652d654a0c1dea9837d226d20018d7a7"

DEST_BIN="$HOME/.local/bin/gnome-theme-switcher"
DEST_DESKTOP="$HOME/.local/share/applications/org.gnome.GTK4ThemeSwitcher.desktop"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

sha256_of() {
    sha256sum "$1" | awk '{print $1}'
}

verify_runtime_dependencies() {
    command -v python3 >/dev/null 2>&1 ||
        die "python3 is unavailable"

    python3 - <<'PY'
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gio, Pango, GLib
print("PASS: PyGObject / GTK4 runtime available")
PY
}

verify_live() {
    echo "=== THEME SWITCHER LIVE VERIFICATION ==="

    [[ -f "$DEST_BIN" ]] ||
        die "missing $DEST_BIN"

    [[ -x "$DEST_BIN" ]] ||
        die "$DEST_BIN is not executable"

    [[ -f "$DEST_DESKTOP" ]] ||
        die "missing $DEST_DESKTOP"

    local script_sha
    script_sha="$(sha256_of "$DEST_BIN")"

    [[ "$script_sha" == "$EXPECTED_SCRIPT_SHA256" ]] ||
        die "Theme Switcher script drift: expected $EXPECTED_SCRIPT_SHA256, found $script_sha"

    echo "PASS: upstream script SHA-256"

    python3 - "$DEST_DESKTOP" "$EXPECTED_DESKTOP_SHA256" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_upstream_sha = sys.argv[2]

data = path.read_bytes()
lines = data.splitlines(keepends=True)

expected_pl = {
    b"Name[pl]=Ustawienia motywu GNOME/GTK",
    b"Comment[pl]=Dostosuj ustawienia motywu GNOME/GTK",
    b"GenericName[pl]=Ustawienia motywu GNOME/GTK",
}

pl_lines = [
    line.rstrip(b"\r\n")
    for line in lines
    if re.match(rb"^(Name|Comment|GenericName)\[pl\]=", line)
]

if len(pl_lines) != 3:
    raise SystemExit(
        f"expected exactly 3 managed Polish desktop fields, found {len(pl_lines)}"
    )

if set(pl_lines) != expected_pl:
    raise SystemExit(
        "managed Polish desktop fields differ from accepted values"
    )

stripped = b"".join(
    line for line in lines
    if not re.match(rb"^(Name|Comment|GenericName)\[pl\]=", line)
)

actual_upstream_sha = hashlib.sha256(stripped).hexdigest()

if actual_upstream_sha != expected_upstream_sha:
    raise SystemExit(
        "desktop upstream content drift: "
        f"expected {expected_upstream_sha}, found {actual_upstream_sha}"
    )

print("PASS: desktop upstream content matches pinned SHA-256")
print("PASS: 3 managed Polish desktop fields match accepted values")
PY

    python3 - "$DEST_BIN" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
compile(source, str(path), "exec")
print("PASS: Theme Switcher Python source compiles")
PY

    verify_runtime_dependencies

    echo "THEME_SWITCHER_VERIFY=PASS"
}

if [[ "${1:-}" == "--verify" ]]; then
    [[ $# -eq 1 ]] || die "usage: $0 [--verify]"
    verify_live
    exit 0
fi

[[ $# -eq 0 ]] || die "usage: $0 [--verify]"

(( EUID != 0 )) ||
    die "run as the desktop user, not as root"

for cmd in curl sha256sum python3 install cp rm mkdir date awk; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "required command missing: $cmd"
done

verify_runtime_dependencies

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

UPSTREAM_SCRIPT="$TMP/gnome-theme-switcher"
UPSTREAM_DESKTOP="$TMP/org.gnome.GTK4ThemeSwitcher.desktop"
EXPECTED_DESKTOP="$TMP/org.gnome.GTK4ThemeSwitcher.desktop.expected"

echo "=== DOWNLOAD PINNED THEME SWITCHER ==="

curl -fL --retry 2 \
    "$UPSTREAM_BASE/gnome-theme-switcher" \
    -o "$UPSTREAM_SCRIPT"

curl -fL --retry 2 \
    "$UPSTREAM_BASE/org.gnome.GTK4ThemeSwitcher.desktop" \
    -o "$UPSTREAM_DESKTOP"

script_sha="$(sha256_of "$UPSTREAM_SCRIPT")"
desktop_sha="$(sha256_of "$UPSTREAM_DESKTOP")"

[[ "$script_sha" == "$EXPECTED_SCRIPT_SHA256" ]] ||
    die "downloaded script SHA-256 mismatch: $script_sha"

[[ "$desktop_sha" == "$EXPECTED_DESKTOP_SHA256" ]] ||
    die "downloaded desktop SHA-256 mismatch: $desktop_sha"

echo "PASS: pinned upstream script"
echo "PASS: pinned upstream desktop"

echo
echo "=== BUILD POLISH DESKTOP ENTRY ==="

python3 - "$UPSTREAM_DESKTOP" "$EXPECTED_DESKTOP" <<'PY'
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

translations = {
    b"Name=GNOME-GTK-Theme-Setting":
        b"Name[pl]=Ustawienia motywu GNOME/GTK\n",
    b"Comment=Tweak GNOME GTK Theme settings":
        b"Comment[pl]=Dostosuj ustawienia motywu GNOME/GTK\n",
    b"GenericName=Tweak GNOME GTK Theme settings":
        b"GenericName[pl]=Ustawienia motywu GNOME/GTK\n",
}

lines = src.read_bytes().splitlines(keepends=True)

for localized_key in (
    b"Name[pl]=",
    b"Comment[pl]=",
    b"GenericName[pl]=",
):
    if any(line.startswith(localized_key) for line in lines):
        raise SystemExit(
            f"upstream unexpectedly already contains {localized_key.decode()}"
        )

out = []
inserted = 0

for line in lines:
    out.append(line)
    key = line.rstrip(b"\r\n")

    if key in translations:
        out.append(translations[key])
        inserted += 1

if inserted != 3:
    raise SystemExit(
        f"expected to insert 3 Polish fields, inserted {inserted}"
    )

dst.write_bytes(b"".join(out))
PY

echo "PASS: deterministic Polish desktop entry built"

echo
echo "=== PREPARE BACKUP ==="

BACKUP_ROOT="$HOME/.local/state/fedora-workstation-setup/backups"

needs_backup=0

if [[ -e "$DEST_BIN" ]] &&
   [[ "$(sha256_of "$DEST_BIN")" != "$EXPECTED_SCRIPT_SHA256" ]]; then
    needs_backup=1
fi

if [[ -e "$DEST_DESKTOP" ]] &&
   ! cmp -s "$EXPECTED_DESKTOP" "$DEST_DESKTOP"; then
    needs_backup=1
fi

BACKUP=""

if (( needs_backup )); then
    BACKUP="$BACKUP_ROOT/theme-switcher-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    chmod 0700 "$BACKUP"

    [[ ! -e "$DEST_BIN" ]] ||
        cp -a "$DEST_BIN" "$BACKUP/gnome-theme-switcher"

    [[ ! -e "$DEST_DESKTOP" ]] ||
        cp -a "$DEST_DESKTOP" "$BACKUP/org.gnome.GTK4ThemeSwitcher.desktop"

    echo "BACKUP=$BACKUP"
else
    echo "BACKUP=NOT_REQUIRED"
fi

echo
echo "=== INSTALL ==="

mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/.local/share/applications"

install -m 0755 \
    "$UPSTREAM_SCRIPT" \
    "$DEST_BIN"

install -m 0644 \
    "$EXPECTED_DESKTOP" \
    "$DEST_DESKTOP"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database \
        "$HOME/.local/share/applications" \
        >/dev/null 2>&1 || true
fi

verify_live

echo "THEME_SWITCHER_INSTALL=PASS"
