#!/usr/bin/env bash
# Fedora 45 KDE Graphite phase 2: curated metadata only, no configuration export.
set -euo pipefail

if [[ "${1:-}" != "--read-only" || $# -ne 1 ]]; then
  printf 'Usage: bash scripts/inventory-kde-graphite-provenance-readonly.sh --read-only\n' >&2
  exit 2
fi

printf 'PROFILE=FEDORA45_KDE_GRAPHITE\nPHASE=PROVENANCE_INVENTORY_V02\nMODE=READ_ONLY\nACCEPTED_BASELINE=NO\nRPM_MULTIARCH_SEPARATOR=SEMICOLON\nRPM_MISSING_SENTINEL=NOT_INSTALLED\n'

if command -v rpm >/dev/null 2>&1; then
  for name in \
    plasma-workspace plasma-desktop kwin kf6-kio kde-cli-tools \
    kf6-kconfig kf6-kwidgetsaddons qt6-qtbase qt6-qtbase-gui \
    xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk \
    pipewire wireplumber flatpak krema kvantum \
    akmod-nvidia akmod-nvidia-open xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda kernel-core; do
    key="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
    # Query an explicit newline-delimited result; a package may have multiple arches
    # or kernel releases. Ignore localized "not installed" messages on rpm failure.
    if versions="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\\n' "$name" 2>/dev/null)"; then
      versions="$(printf '%s\n' "$versions" | LC_ALL=C sort -u | paste -sd ';' -)"
      printf 'RPM_%s=%s\n' "$key" "${versions:-NOT_INSTALLED}"
    else
      printf 'RPM_%s=NOT_INSTALLED\n' "$key"
    fi
  done
else
  printf 'RPM=UNAVAILABLE\n'
fi

if command -v git >/dev/null 2>&1; then
  source_tree="$HOME/Pobrane/Finder-KDE-LAB/source"
  if git -C "$source_tree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'FINDER_SOURCE_GIT_HEAD=%s\n' "$(git -C "$source_tree" rev-parse HEAD)"
    count="$(git -C "$source_tree" status --porcelain=v1 --untracked-files=no | wc -l)"
    printf 'FINDER_SOURCE_TRACKED_CHANGE_COUNT=%s\n' "${count//[[:space:]]/}"
    printf 'FINDER_SOURCE_REMOTE_URL_EXPORTED=NO\n'
  else
    printf 'FINDER_SOURCE_GIT_HEAD=UNAVAILABLE\n'
  fi
else
  printf 'GIT=UNAVAILABLE\n'
fi

lab="$HOME/Pobrane/Finder-KDE-LAB"
for item in \
  'FINDER_P0B2_BIN:build-p0b2-v01/bin/finder' \
  'FINDER_QSS_P0B2:finder-menu-tahoe-kde-v15-progress-p0b2-v01.qss' \
  'FINDER_QSS_CHARCOAL_V04:finder-menu-tahoe-kde-v15-progress-p0b2-charcoal-v04.qss'; do
  label="${item%%:*}"
  relative="${item#*:}"
  if [[ -f "$lab/$relative" ]] && command -v sha256sum >/dev/null 2>&1; then
    digest="$(sha256sum "$lab/$relative")"
    printf '%s_SHA256=%s\n' "$label" "${digest%% *}"
  else
    printf '%s_SHA256=UNAVAILABLE\n' "$label"
  fi
done

printf 'PRIVATE_CONFIG_CONTENTS_EXPORTED=NO\n'
printf 'USER_PATHS_EXPORTED=NO\n'
printf 'NETWORK_REQUESTS=NO\n'
printf 'CHANGES_APPLIED=NO\n'
printf 'INVENTORY_RESULT=READ_ONLY_COMPLETE\n'
