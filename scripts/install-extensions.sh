#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$ROOT_DIR/gnome/enabled-extensions.txt"
INVENTORY="$ROOT_DIR/gnome/extensions-inventory.tsv"

command -v gnome-extensions >/dev/null 2>&1 || {
  echo "ERROR: gnome-extensions command is unavailable." >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip is required." >&2; exit 1; }
command -v glib-compile-schemas >/dev/null 2>&1 || { echo "ERROR: glib-compile-schemas is required." >&2; exit 1; }

[[ -f "$LIST" ]] || { echo "ERROR: missing $LIST" >&2; exit 1; }
[[ -f "$INVENTORY" ]] || { echo "ERROR: missing $INVENTORY" >&2; exit 1; }

shell_major="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

compile_extension_schemas() {
  local uuid="$1" dest="$2" schema_dir="$2/schemas"
  [[ -d "$schema_dir" ]] || return 0

  if compgen -G "$schema_dir/*.gschema.xml" >/dev/null; then
    echo "SCHEMA: compiling $uuid"
    if ! glib-compile-schemas "$schema_dir"; then
      echo "ERROR: failed to compile GSettings schemas for $uuid." >&2
      return 1
    fi
    [[ -f "$schema_dir/gschemas.compiled" ]] || {
      echo "ERROR: gschemas.compiled was not created for $uuid." >&2
      return 1
    }
  fi
}

# extensions.gnome.org stores pinned archives as:
#   extension-data/<UUID-with-@-removed>.v<VERSION>.shell-extension.zip
# Dots in the UUID are preserved. Replacing both '@' and '.' with underscores
# produced invalid URLs and caused clean restores to receive HTTP 404.
install_ego() {
  local uuid="$1" version="$2" dest zip url archive_uuid
  [[ -n "$version" ]] || return 2
  dest="$HOME/.local/share/gnome-shell/extensions/$uuid"
  zip="$tmp/${uuid//\//_}.zip"
  archive_uuid="${uuid//@/}"
  url="https://extensions.gnome.org/extension-data/${archive_uuid}.v${version}.shell-extension.zip"

  echo "INSTALL: $uuid v$version"
  if ! curl -fL --retry 2 -o "$zip" "$url"; then
    echo "WARN: pinned archive unavailable for $uuid v$version; leaving it unresolved." >&2
    return 1
  fi

  if ! unzip -tq "$zip" >/dev/null 2>&1; then
    echo "WARN: downloaded archive is invalid for $uuid v$version." >&2
    return 1
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -q "$zip" -d "$dest"

  if [[ ! -f "$dest/metadata.json" ]]; then
    echo "WARN: $uuid v$version archive has no metadata.json." >&2
    rm -rf "$dest"
    return 1
  fi

  if ! grep -q "\"$shell_major\"" "$dest/metadata.json" 2>/dev/null; then
    echo "WARN: $uuid v$version does not declare GNOME $shell_major compatibility." >&2
  fi

  compile_extension_schemas "$uuid" "$dest" || {
    rm -rf "$dest"
    return 1
  }
}

# Build UUID -> version/location lookup from the audited workstation.
declare -A versions locations
while IFS=$'\t' read -r uuid _name version _shells _url location; do
  [[ "$uuid" == "uuid" || -z "$uuid" ]] && continue
  versions["$uuid"]="$version"
  locations["$uuid"]="$location"
done < "$INVENTORY"

missing=0
while IFS= read -r uuid; do
  [[ -z "$uuid" || "$uuid" == \#* ]] && continue
  if gnome-extensions info "$uuid" >/dev/null 2>&1; then
    printf 'OK:   %s\n' "$uuid"
    ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    if [[ -d "$ext_dir" ]] && ! compile_extension_schemas "$uuid" "$ext_dir"; then
      missing=$((missing + 1))
    fi
    continue
  fi

  location="${locations[$uuid]:-}"
  version="${versions[$uuid]:-}"
  if [[ "$location" == /usr/share/* ]]; then
    printf 'MISS(system): %s — install via Fedora package manager.\n' "$uuid"
    missing=$((missing + 1))
  elif install_ego "$uuid" "$version"; then
    printf 'DONE: %s\n' "$uuid"
  else
    printf 'MISS(user): %s\n' "$uuid"
    missing=$((missing + 1))
  fi
done < "$LIST"

if (( missing > 0 )); then
  printf 'ERROR: %d required extension(s) remain unresolved.\n' "$missing" >&2
  exit 1
fi

echo "All required GNOME extensions are present and user-extension schemas are compiled."
echo "Log out and back in before enabling newly installed extensions."
