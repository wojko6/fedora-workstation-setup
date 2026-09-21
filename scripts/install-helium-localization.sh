#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGE="helium-bin"
PATCHER_SRC="$ROOT_DIR/scripts/helium_datapack.py"
HELPER_SRC="$ROOT_DIR/scripts/helium-localization-post-transaction.sh"
OVERLAY_SRC="$ROOT_DIR/localization/helium/v0.17.2.1-pl-completion.json"
ACTION_SRC="$ROOT_DIR/system/dnf5/actions.d/90-helium-localization.actions"

PATCHER_DST="/usr/local/libexec/fedora-workstation-setup/helium_datapack.py"
HELPER_DST="/usr/local/libexec/fedora-workstation-setup/helium-localization-post-transaction"
OVERLAY_DST="/usr/local/share/fedora-workstation-setup/helium/pl-completion.json"
ACTION_DST="/etc/dnf/libdnf5-plugins/actions.d/90-helium-localization.actions"

for cmd in rpm python3 sudo install cmp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: Helium RPM is not installed"
    exit 0
fi

for path in "$PATCHER_SRC" "$HELPER_SRC" "$OVERLAY_SRC" "$ACTION_SRC"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required Helium localization source missing: $path" >&2
        exit 1
    }
done

python3 "$PATCHER_SRC" self-test
python3 "$PATCHER_SRC" validate-overlay --overlay "$OVERLAY_SRC"

if ! rpm -q libdnf5-plugin-actions >/dev/null 2>&1; then
    echo "==> Installing DNF5 actions plugin for Helium post-update localization"
    sudo dnf install -y libdnf5-plugin-actions
fi

sudo install -D -m 0755 "$PATCHER_SRC" "$PATCHER_DST"
sudo install -D -m 0755 "$HELPER_SRC" "$HELPER_DST"
sudo install -D -m 0644 "$OVERLAY_SRC" "$OVERLAY_DST"
sudo install -D -m 0644 "$ACTION_SRC" "$ACTION_DST"

if [[ -f /etc/dnf/libdnf5-plugins/actions.conf ]] &&
   grep -Eiq '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*(0|false|no)[[:space:]]*$'        /etc/dnf/libdnf5-plugins/actions.conf; then
    echo "FAIL: DNF5 actions plugin is explicitly disabled in actions.conf" >&2
    exit 1
fi

sudo "$HELPER_DST"

bash "$ROOT_DIR/scripts/verify-helium-localization.sh"

echo "PASS: Helium Polish localization persistence installed"
echo "Restart Helium to reload the translated DataPack if the browser is currently open."
