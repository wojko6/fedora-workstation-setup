#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/packages/flatpak.txt"

command -v flatpak >/dev/null || {
  echo "ERROR: flatpak is not installed." >&2
  exit 1
}

if [[ ! -r "$MANIFEST" ]]; then
  echo "ERROR: required Flatpak manifest missing or unreadable: $MANIFEST" >&2
  exit 1
fi

# The repository-managed Flatpaks are deliberately system-scoped. This matches
# localization/verifier code that operates on the system Flatpak deployment and
# avoids accepting an unrelated per-user Flathub remote or application.
if ! flatpak remotes --system --columns=name | grep -Fxq flathub; then
  sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

while IFS= read -r app; do
  [[ -z "$app" || "$app" == \#* ]] && continue
  sudo flatpak install --system -y flathub "$app"
done < "$MANIFEST"
