#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/packages/rpm.txt"

mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")

if (( ${#packages[@]} == 0 )); then
  echo "RPM manifest is not populated yet; skipping."
  exit 0
fi

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
  echo "No RPM packages remain to install; skipping."
  exit 0
fi

sudo dnf install -y "${packages[@]}"
