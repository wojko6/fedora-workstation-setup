#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$ROOT_DIR/gnome/enabled-extensions.txt"
INVENTORY="$ROOT_DIR/gnome/extensions-inventory.tsv"
LOCK="$ROOT_DIR/gnome/extensions-lock.tsv"
TREE_LOCK="$ROOT_DIR/gnome/extensions-tree-lock.tsv"
TREE_HELPER="$ROOT_DIR/scripts/extension_tree_integrity.py"
EGO_VERIFIER="$ROOT_DIR/scripts/verify_ego_extension.py"
GITHUB_METADATA_PREPARER="$ROOT_DIR/scripts/prepare_github_extension_metadata.py"

command -v gnome-extensions >/dev/null 2>&1 || {
  echo "ERROR: gnome-extensions command is unavailable." >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip is required." >&2; exit 1; }
command -v glib-compile-schemas >/dev/null 2>&1 || { echo "ERROR: glib-compile-schemas is required." >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "ERROR: tar is required." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required." >&2; exit 1; }

[[ -f "$LIST" ]] || { echo "ERROR: missing $LIST" >&2; exit 1; }
[[ -f "$INVENTORY" ]] || { echo "ERROR: missing $INVENTORY" >&2; exit 1; }
[[ -f "$LOCK" ]] || { echo "ERROR: missing $LOCK" >&2; exit 1; }
[[ -f "$EGO_VERIFIER" ]] || {
  echo "ERROR: missing $EGO_VERIFIER" >&2
  exit 1
}
[[ -f "$GITHUB_METADATA_PREPARER" ]] || {
  echo "ERROR: missing $GITHUB_METADATA_PREPARER" >&2
  exit 1
}
[[ -f "$TREE_HELPER" ]] || {
  echo "ERROR: missing $TREE_HELPER" >&2
  exit 1
}

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

installed_version() {
  local uuid="$1"
  gnome-extensions info "$uuid" 2>/dev/null \
    | sed -nE 's/^[[:space:]]*(Version|Wersja):[[:space:]]*//p' \
    | head -n 1
}

version_matches() {
  local current="$1" expected="$2"
  [[ -n "$current" && ( "$current" == "$expected" || "$current" =~ \("$expected"\)$ ) ]]
}

# Ordinary EGO-sourced extensions use their audited runtime version as the
# archive version. Extensions with another reproducible source are described
# explicitly in extensions-lock.tsv.
ego_archive_version() {
  local _uuid="$1" runtime_version="$2"
  printf '%s\n' "$runtime_version"
}

# extensions.gnome.org stores pinned archives as:
#   extension-data/<UUID-with-@-removed>.v<VERSION>.shell-extension.zip
# Dots in the UUID are preserved. Replacing both '@' and '.' with underscores
# produced invalid URLs and caused clean restores to receive HTTP 404.
install_ego() {
  local uuid="$1" archive_version="$2" expected_sha256="$3"
  local dest zip url archive_uuid stage parent backup

  [[ -n "$archive_version" ]] || return 2

  if [[ ! "$expected_sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: missing or invalid SHA-256 lock for $uuid." >&2
    return 1
  fi

  dest="$HOME/.local/share/gnome-shell/extensions/$uuid"
  parent="$(dirname "$dest")"
  zip="$tmp/${uuid//\//_}.zip"
  stage="$parent/.${uuid}.restore.$$"
  backup="$parent/.${uuid}.backup.$$"

  archive_uuid="${uuid//@/}"
  url="https://extensions.gnome.org/extension-data/${archive_uuid}.v${archive_version}.shell-extension.zip"

  echo "INSTALL: $uuid EGO v$archive_version"

  if ! curl -fL --retry 2 -o "$zip" "$url"; then
    echo "WARN: pinned archive unavailable for $uuid EGO v$archive_version; leaving it unresolved." >&2
    return 1
  fi

  if ! python3 "$EGO_VERIFIER" \
      --archive "$zip" \
      --sha256 "$expected_sha256" \
      --uuid "$uuid" \
      --version "$archive_version" \
      --shell-major "$shell_major"; then
    echo "WARN: security verification failed for $uuid EGO v$archive_version." >&2
    return 1
  fi

  mkdir -p "$parent"
  rm -rf "$stage" "$backup"
  mkdir -p "$stage"

  if ! unzip -q "$zip" -d "$stage"; then
    echo "WARN: failed to extract $uuid EGO v$archive_version." >&2
    rm -rf "$stage"
    return 1
  fi

  if ! compile_extension_schemas "$uuid" "$stage"; then
    rm -rf "$stage"
    return 1
  fi

  if [[ -e "$dest" ]]; then
    if ! mv "$dest" "$backup"; then
      echo "WARN: failed to preserve existing $uuid installation." >&2
      rm -rf "$stage"
      return 1
    fi
  fi

  if mv "$stage" "$dest"; then
    rm -rf "$backup"
  else
    echo "WARN: failed to install $uuid EGO v$archive_version; restoring previous installation." >&2
    rm -rf "$dest"

    if [[ -e "$backup" ]]; then
      mv "$backup" "$dest"
    fi

    return 1
  fi

  return 0
}

install_github_commit() {
  local uuid="$1" runtime_version="$2" repo_url="$3" commit="$4"
  local dest parent archive stage backup

  [[ -n "$runtime_version" && -n "$repo_url" && -n "$commit" ]] || return 2

  repo_url="${repo_url%.git}"

  if [[ "$repo_url" != https://github.com/*/* ]]; then
    echo "WARN: unsupported GitHub source URL for $uuid: $repo_url" >&2
    return 1
  fi

  dest="$HOME/.local/share/gnome-shell/extensions/$uuid"
  parent="$(dirname "$dest")"
  archive="$tmp/${uuid//\//_}.${commit}.tar.gz"
  stage="$parent/.${uuid}.restore.$$"
  backup="$parent/.${uuid}.backup.$$"

  echo "INSTALL: $uuid GitHub commit $commit"

  if ! curl -fL --retry 2 \
      -o "$archive" \
      "$repo_url/archive/$commit.tar.gz"; then
    echo "WARN: pinned GitHub commit unavailable for $uuid: $commit" >&2
    return 1
  fi

  if ! tar -tzf "$archive" >/dev/null 2>&1; then
    echo "WARN: downloaded GitHub archive is invalid for $uuid." >&2
    return 1
  fi

  mkdir -p "$parent"
  rm -rf "$stage" "$backup"
  mkdir -p "$stage"

  if ! tar -xzf "$archive" --strip-components=1 -C "$stage"; then
    echo "WARN: failed to extract GitHub source for $uuid." >&2
    rm -rf "$stage"
    return 1
  fi

  if ! python3 "$GITHUB_METADATA_PREPARER" \
      --metadata "$stage/metadata.json" \
      --uuid "$uuid" \
      --version "$runtime_version" \
      --shell-major "$shell_major"; then
    echo "WARN: strict metadata validation/preparation failed for $uuid." >&2
    rm -rf "$stage"
    return 1
  fi

  rm -rf \
    "$stage/.gitignore" \
    "$stage/LICENSE" \
    "$stage/Makefile" \
    "$stage/README.md" \
    "$stage/media"

  if ! compile_extension_schemas "$uuid" "$stage"; then
    rm -rf "$stage"
    return 1
  fi

  if [[ -e "$dest" ]]; then
    if ! mv "$dest" "$backup"; then
      echo "WARN: failed to preserve existing $uuid installation." >&2
      rm -rf "$stage"
      return 1
    fi
  fi

  if mv "$stage" "$dest"; then
    rm -rf "$backup"
  else
    echo "WARN: failed to install $uuid; restoring previous installation." >&2
    rm -rf "$dest"

    if [[ -e "$backup" ]]; then
      mv "$backup" "$dest"
    fi

    return 1
  fi

  return 0
}

install_user_extension() {
  local uuid="$1" expected_version="$2"
  local source="${lock_sources[$uuid]:-}"
  local source_ref="${lock_refs[$uuid]:-}"

  if [[ -z "$source" ]]; then
    printf 'ERROR: no source lock exists for user extension %s\n' "$uuid" >&2
    return 1
  fi

  case "$source" in
    github-commit)
      if [[ "${lock_versions[$uuid]:-}" != "$expected_version" ]]; then
        printf 'ERROR: lock/inventory runtime mismatch for %s: lock=%s inventory=%s\n' \
          "$uuid" "${lock_versions[$uuid]:-missing}" "$expected_version" >&2
        return 1
      fi

      install_github_commit \
        "$uuid" \
        "$expected_version" \
        "${urls[$uuid]:-}" \
        "$source_ref"
      ;;

    ego)
      install_ego \
        "$uuid" \
        "$(ego_archive_version "$uuid" "$expected_version")" \
        "${lock_hashes[$uuid]:-}"
      ;;

    *)
      printf 'ERROR: unsupported extension source for %s: %s\n' \
        "$uuid" "$source" >&2
      return 1
      ;;
  esac
}

# Build UUID -> runtime-version/location/source lookup from the audited workstation.
declare -A versions locations urls
while IFS=$'\t' read -r uuid _name version _shells url location; do
  [[ "$uuid" == "uuid" || -z "$uuid" ]] && continue
  versions["$uuid"]="$version"
  locations["$uuid"]="$location"
  urls["$uuid"]="$url"
done < "$INVENTORY"

declare -A lock_versions lock_sources lock_refs lock_hashes
while IFS=$'\t' read -r uuid runtime_version source source_ref sha256; do
  [[ "$uuid" == "uuid" || -z "$uuid" ]] && continue

  if [[ -z "${versions[$uuid]:-}" ]]; then
    printf 'ERROR: lock contains unknown extension: %s\n' "$uuid" >&2
    exit 1
  fi

  if [[ "${versions[$uuid]}" != "$runtime_version" ]]; then
    printf 'ERROR: lock/inventory runtime mismatch for %s: lock=%s inventory=%s\n' \
      "$uuid" "$runtime_version" "${versions[$uuid]}" >&2
    exit 1
  fi

  lock_versions["$uuid"]="$runtime_version"
  lock_sources["$uuid"]="$source"
  lock_refs["$uuid"]="$source_ref"
  lock_hashes["$uuid"]="$sha256"
done < "$LOCK"

check_installed_tree_integrity() {
  local uuid="$1"
  local expected_version="$2"
  local ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"

  [[ -f "$TREE_LOCK" ]] || return 2

  python3 "$TREE_HELPER" check-one     --lock "$TREE_LOCK"     --uuid "$uuid"     --version "$expected_version"     --path "$ext_dir"
}

missing=0
while IFS= read -r uuid; do
  [[ -z "$uuid" || "$uuid" == \#* ]] && continue

  location="${locations[$uuid]:-}"
  expected_version="${versions[$uuid]:-}"

  if gnome-extensions info "$uuid" >/dev/null 2>&1; then
    current_version="$(installed_version "$uuid")"

    if [[ "$location" != /usr/share/* && -n "$expected_version" ]]; then
      needs_restore=0

      if ! version_matches "$current_version" "$expected_version"; then
        printf 'DRIFT: %s expected runtime version %s, found %s\n' \
          "$uuid" "$expected_version" "${current_version:-unknown}"
        needs_restore=1
      elif [[ -f "$TREE_LOCK" ]]; then
        tree_output=""
        if tree_output="$(check_installed_tree_integrity "$uuid" "$expected_version" 2>&1)"; then
          printf '%s\n' "$tree_output"
        else
          tree_rc=$?
          printf '%s\n' "$tree_output" >&2

          if (( tree_rc == 3 )); then
            needs_restore=1
          else
            printf 'ERROR: extension tree integrity evaluation failed for %s\n' "$uuid" >&2
            missing=$((missing + 1))
            continue
          fi
        fi
      fi

      if (( needs_restore )); then
        printf 'RESTORE: reinstalling pinned source %s\n' "${lock_sources[$uuid]:-missing-lock}"

        if install_user_extension "$uuid" "$expected_version"; then
          printf 'DONE: restored %s from pinned source\n' "$uuid"
        else
          printf 'MISS(user): %s\n' "$uuid"
          missing=$((missing + 1))
        fi
        continue
      fi
    fi

    printf 'OK:   %s%s\n' "$uuid" \
      "${current_version:+ (runtime version $current_version)}"
    ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    if [[ -d "$ext_dir" ]] && ! compile_extension_schemas "$uuid" "$ext_dir"; then
      missing=$((missing + 1))
    fi
    continue
  fi

  if [[ "$location" == /usr/share/* ]]; then
    printf 'MISS(system): %s — install via Fedora package manager.\n' "$uuid"
    missing=$((missing + 1))
  elif install_user_extension "$uuid" "$expected_version"; then
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

echo "All required GNOME extensions are present at the accepted runtime pins and user-extension schemas are compiled."
echo "Log out and back in before enabling newly installed or replaced extensions."
