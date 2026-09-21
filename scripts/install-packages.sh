#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/packages/rpm.txt"
ABSENT_MANIFEST="$ROOT_DIR/packages/rpm-absent.txt"

# Both manifests are part of the required desired-state contract. Validate them
# before the first package mutation so a damaged checkout cannot silently
# degrade into a successful partial restore.
for manifest in "$MANIFEST" "$ABSENT_MANIFEST"; do
  if [[ ! -r "$manifest" ]]; then
    echo "ERROR: required package manifest missing or unreadable: $manifest" >&2
    exit 1
  fi
done

mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")

if (( ${#packages[@]} == 0 )); then
  echo "ERROR: required RPM manifest is empty: $MANIFEST" >&2
  exit 1
fi

mapfile -t absent_packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ABSENT_MANIFEST")

# These packages describe the physical workstation host. Installing them inside
# a guest VM is unnecessary and can pull in host-only kernel modules/drivers.
host_hardware_packages=(
  VirtualBox
  akmod-VirtualBox
  akmod-nvidia
  xorg-x11-drv-nvidia-cuda
)

virt="none"
if command -v systemd-detect-virt >/dev/null 2>&1; then
  virt="$(systemd-detect-virt 2>/dev/null || true)"
  [[ -n "$virt" ]] || virt="none"
fi

if [[ "$virt" != "none" ]]; then
  echo "Virtualization detected: $virt"
  echo "Skipping physical-host hardware packages:"
  printf '  SKIP: %s\n' "${host_hardware_packages[@]}"

  filtered_packages=()
  for package in "${packages[@]}"; do
    skip=0
    for host_package in "${host_hardware_packages[@]}"; do
      if [[ "$package" == "$host_package" ]]; then
        skip=1
        break
      fi
    done
    (( skip == 0 )) && filtered_packages+=("$package")
  done
  packages=("${filtered_packages[@]}")
else
  echo "Physical host detected; installing the complete RPM manifest."
fi

if (( ${#packages[@]} == 0 )); then
  echo "No RPM packages remain to install in this environment; skipping installation."
else
  # Fedora Workstation ships ffmpeg-free. The desired workstation manifest uses
  # RPM Fusion's full ffmpeg build, and the two packages conflict by design.
  # Perform this one known replacement explicitly instead of enabling
  # --allowerasing for the entire workstation package transaction.
  if printf '%s\n' "${packages[@]}" | grep -Fxq ffmpeg && rpm -q ffmpeg-free >/dev/null 2>&1; then
    echo "==> Replacing Fedora ffmpeg-free with RPM Fusion ffmpeg"
    sudo dnf install -y --allowerasing ffmpeg
  fi

  sudo dnf install -y "${packages[@]}"
fi

remove_packages=()

for package in "${absent_packages[@]}"; do
  if rpm -q "$package" >/dev/null 2>&1; then
    remove_packages+=("$package")
  fi
done

if (( ${#remove_packages[@]} > 0 )); then
  echo "==> Removing packages excluded from desired state"
  printf '  REMOVE: %s\n' "${remove_packages[@]}"
  sudo dnf remove -y --no-autoremove "${remove_packages[@]}"
else
  echo "OK: excluded RPM packages are already absent"
fi
