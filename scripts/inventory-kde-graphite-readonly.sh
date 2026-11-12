#!/usr/bin/env bash
# Read-only, privacy-minimizing Fedora 45/KDE Graphite inventory.
# No root privileges, network access, configuration writes or raw config export.
set -euo pipefail

usage() {
  printf 'Usage: bash scripts/inventory-kde-graphite-readonly.sh --read-only\n' >&2
}

if [[ "$#" -ne 1 || "${1:-}" != "--read-only" ]]; then
  usage
  exit 2
fi

show_presence() {
  local label="$1" path="$2"
  if [[ -r "$path" ]]; then
    printf '%s=PRESENT\n' "$label"
  else
    printf '%s=ABSENT\n' "$label"
  fi
}

show_command() {
  local label="$1" tool="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s=AVAILABLE\n' "$label"
  else
    printf '%s=NOT_FOUND\n' "$label"
  fi
}

printf 'PROFILE=FEDORA45_KDE_GRAPHITE\n'
printf 'MODE=READ_ONLY\n'
printf 'ACCEPTED_BASELINE=NO\n'

if [[ -r /etc/os-release ]]; then
  # The local distribution release file is OS-managed; it is not user config.
  # shellcheck disable=SC1091
  source /etc/os-release
  printf 'OS_ID=%s\n' "${ID:-unknown}"
  printf 'OS_VERSION_ID=%s\n' "${VERSION_ID:-unknown}"
fi

printf 'SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-unknown}"
printf 'DESKTOP_SESSION=%s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
printf 'KERNEL_RELEASE=%s\n' "$(uname -r)"

show_command TOOL_RPM rpm
show_command TOOL_DNF5 dnf5
show_command TOOL_FLATPAK flatpak
show_command TOOL_CMAKE cmake
show_command TOOL_NINJA ninja
show_command TOOL_KREMA krema
show_command TOOL_PLASMASHELL plasmashell
show_command TOOL_DOLPHIN dolphin
show_command TOOL_KREADCONFIG6 kreadconfig6

if command -v rpm >/dev/null 2>&1; then
  for pkg in plasma-workspace kwin kf6-kio kde-cli-tools; do
    key="$(printf '%s' "$pkg" | tr '[:lower:]-' '[:upper:]_')"
    version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null || true)"
    printf 'PKG_%s=%s\n' "$key" "${version:-NOT_INSTALLED}"
  done
fi

show_presence KDEGLOBALS "$HOME/.config/kdeglobals"
show_presence KWINRC "$HOME/.config/kwinrc"
show_presence KGLOBALSHORTCUTSRC "$HOME/.config/kglobalshortcutsrc"
show_presence PLASMA_APPLETSRC "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

lab="$HOME/Pobrane/Finder-KDE-LAB"
show_presence FINDER_SOURCE "$lab/source/src/dolphinnavigatorswidgetaction.cpp"
show_presence FINDER_P0B2_BINARY "$lab/build-p0b2-v01/bin/finder"
show_presence FINDER_QSS_V04 "$lab/finder-menu-tahoe-kde-v15-progress-p0b2-charcoal-v04.qss"

if [[ -r "$lab/finder-menu-tahoe-kde-v15-progress-p0b2-charcoal-v04.qss" ]] && command -v sha256sum >/dev/null 2>&1; then
  digest="$(sha256sum "$lab/finder-menu-tahoe-kde-v15-progress-p0b2-charcoal-v04.qss")"
  printf 'FINDER_QSS_V04_SHA256=%s\n' "${digest%% *}"
fi

printf 'CONFIG_CONTENTS_EXPORTED=NO\n'
printf 'MACHINE_IDENTIFIERS_EXPORTED=NO\n'
printf 'CHANGES_APPLIED=NO\n'
printf 'INVENTORY_RESULT=READ_ONLY_COMPLETE\n'
