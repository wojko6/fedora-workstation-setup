#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

LAUNCHERS_DIR="$ROOT_DIR/desktop/launchers"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="${XDG_DESKTOP_DIR:-$HOME/Pulpit}"

ASUS_CONF="$LAUNCHERS_DIR/asus-router.conf"
ASUS_TEMPLATE="$LAUNCHERS_DIR/asus-router.desktop.template"
ASUS_RENDERER="$ROOT_DIR/scripts/render-asus-launcher.py"

STEAM_DESKTOP="/usr/share/applications/steam.desktop"
BRAVE_DESKTOP="/usr/share/applications/brave-origin.desktop"

GFN_APP="com.nvidia.geforcenow"
GFN_DESKTOP="$HOME/.local/share/flatpak/exports/share/applications/$GFN_APP.desktop"

mkdir -p "$APPS_DIR" "$DESKTOP_DIR"

install_app_launcher() {
    local src="$1"
    local name="$2"

    install -m 0644 "$src" "$APPS_DIR/$name"
    printf 'INSTALLED APP: %s\n' "$name"
}

install_desktop_launcher() {
    local src="$1"
    local name="$2"

    install -m 0644 "$src" "$DESKTOP_DIR/$name"
    printf 'INSTALLED DESKTOP: %s\n' "$name"
}

managed_desktop_name() {
    local name="$1"

    case "$name" in
        steam.desktop)
            return 0
            ;;
        brave-origin.desktop)
            return 0
            ;;
        com.nvidia.geforcenow.desktop)
            return 0
            ;;
        asus-router.desktop)
            [[ -f "$ASUS_CONF" ]]
            return
            ;;
        *)
            return 1
            ;;
    esac
}

quarantine_unmanaged_desktop_entries() {
    local backup_root
    local backup=""
    local entry
    local name
    local -a entries

    backup_root="$HOME/.local/state/fedora-workstation-setup/desktop-pre-restore"

    shopt -s nullglob dotglob
    entries=("$DESKTOP_DIR"/*)
    shopt -u nullglob dotglob

    for entry in "${entries[@]}"; do
        name="$(basename -- "$entry")"

        if managed_desktop_name "$name"; then
            continue
        fi

        if [[ -z "$backup" ]]; then
            mkdir -p "$backup_root"
            chmod 0700 "$backup_root"

            backup="$(mktemp -d "$backup_root/restore-XXXXXXXX")"
            chmod 0700 "$backup"

            printf 'DESKTOP BACKUP: %s\n' "$backup"
        fi

        mv -- "$entry" "$backup/"
        printf 'BACKED UP DESKTOP ENTRY: %s\n' "$name"
    done
}

# Restore policy:
#
# physical files:
#   ASUS SSH
#   Steam
#   Brave Origin
#   NVIDIA GeForce NOW
#
# DING supplies:
#   Home
#   Trash
#
# Unexpected pre-existing physical entries are preserved in backup.
quarantine_unmanaged_desktop_entries

# Counter-Strike 2 remains available from the application menu only.
install_app_launcher \
    "$LAUNCHERS_DIR/counter-strike-2.desktop" \
    "Counter-Strike 2.desktop"

# Steam and Brave are repository-managed RPM applications.
for path in "$STEAM_DESKTOP" "$BRAVE_DESKTOP"; do
    [[ -f "$path" ]] || {
        echo "ERROR: required packaged desktop launcher missing: $path" >&2
        exit 1
    }
done

install_desktop_launcher \
    "$STEAM_DESKTOP" \
    "steam.desktop"

install_desktop_launcher \
    "$BRAVE_DESKTOP" \
    "brave-origin.desktop"

# GeForce NOW is installed earlier as the official NVIDIA user Flatpak.
flatpak info --user "$GFN_APP" >/dev/null 2>&1 || {
    echo "ERROR: required GeForce NOW user Flatpak missing: $GFN_APP" >&2
    exit 1
}

[[ -e "$GFN_DESKTOP" ]] || {
    echo "ERROR: GeForce NOW desktop export missing: $GFN_DESKTOP" >&2
    exit 1
}

install_desktop_launcher \
    "$GFN_DESKTOP" \
    "com.nvidia.geforcenow.desktop"

# ASUS SSH requires private, gitignored connection data.
if [[ -f "$ASUS_CONF" ]]; then
    command -v python3 >/dev/null 2>&1 || {
        echo "ERROR: python3 is required to render the ASUS launcher." >&2
        exit 1
    }

    for path in "$ASUS_TEMPLATE" "$ASUS_RENDERER"; do
        [[ -f "$path" ]] || {
            echo "ERROR: required ASUS launcher source missing: $path" >&2
            exit 1
        }
    done

    DDTERM_BIN="$HOME/.local/share/gnome-shell/extensions/ddterm@amezin.github.com/bin/com.github.amezin.ddterm"

    [[ -x "$DDTERM_BIN" ]] || {
        echo "ERROR: ddterm command not executable: $DDTERM_BIN" >&2
        exit 1
    }

    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    python3 "$ASUS_RENDERER" \
        --config "$ASUS_CONF" \
        --template "$ASUS_TEMPLATE" \
        --ddterm-bin "$DDTERM_BIN" \
        --output "$tmp" \
        --check-key-file

    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$tmp"
    fi

    install_app_launcher \
        "$tmp" \
        "asus-router.desktop"

    install_desktop_launcher \
        "$tmp" \
        "asus-router.desktop"
else
    printf 'SKIP: ASUS launcher config not found: %s\n' "$ASUS_CONF"
    printf '      Restore the private config before install.sh to recreate ASUS SSH.\n'
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi

echo "PASS: launcher restore policy applied"
