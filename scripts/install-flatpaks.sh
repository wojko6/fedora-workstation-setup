#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/packages/flatpak.txt"

command -v flatpak >/dev/null || { echo "ERROR: flatpak is not installed." >&2; exit 1; }

if ! flatpak remotes --columns=name | grep -Fxq flathub; then
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

while IFS= read -r app; do
  [[ -z "$app" || "$app" == \#* ]] && continue
  flatpak install -y flathub "$app"
done < "$MANIFEST"
