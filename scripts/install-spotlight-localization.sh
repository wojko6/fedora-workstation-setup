#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="spotlight@nin"
DOMAIN="spotlight"
EXPECTED_VERSION="14"
EXPECTED_VERSION_NAME="2026.11"
SOURCE_PO="$ROOT_DIR/localization/spotlight/pl.po"
PATCH_DIR="$ROOT_DIR/patches/gnome-extensions/spotlight"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
LOCALE_DIR="$EXT_DIR/locale/pl/LC_MESSAGES"
TARGET_MO="$LOCALE_DIR/$DOMAIN.mo"
BACKUP_DIR="$EXT_DIR/.localization-backup-v14-2026.11"

for cmd in python3 msgfmt patch; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "FAIL: required command unavailable: $cmd" >&2
    exit 1
  }
done

if [[ ! -d "$EXT_DIR" ]]; then
  echo "SKIP: Spotlight is not installed: $UUID"
  exit 0
fi

[[ -f "$METADATA" ]] || { echo "FAIL: missing Spotlight metadata: $METADATA" >&2; exit 1; }
[[ -f "$SOURCE_PO" ]] || { echo "FAIL: missing Polish translation source: $SOURCE_PO" >&2; exit 1; }
[[ -d "$PATCH_DIR" ]] || { echo "FAIL: missing Spotlight patch directory: $PATCH_DIR" >&2; exit 1; }

read -r version version_name < <(
  python3 - "$METADATA" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("version", ""), data.get("version-name", ""))
PY
)

if [[ "$version" != "$EXPECTED_VERSION" || "$version_name" != "$EXPECTED_VERSION_NAME" ]]; then
  echo "FAIL: Spotlight version changed; re-audit localization before applying (expected ${EXPECTED_VERSION}/${EXPECTED_VERSION_NAME}, found ${version:-?}/${version_name:-?})" >&2
  exit 1
fi

files=(
  metadata.json
  prefs.js
  prefs/shortcutPage.js
  prefs/appearancePage.js
  prefs/aboutPage.js
)

for rel in "${files[@]}"; do
  [[ -f "$EXT_DIR/$rel" ]] || {
    echo "FAIL: Spotlight v14 source file missing: $rel" >&2
    exit 1
  }
done

# Keep a pristine, version-specific baseline so repeated runs never patch an
# already modified source tree and a same-version reinstall can be restored.
if [[ ! -d "$BACKUP_DIR" ]]; then
  mkdir -p "$BACKUP_DIR/prefs"
  for rel in "${files[@]}"; do
    cp -a "$EXT_DIR/$rel" "$BACKUP_DIR/$rel"
  done
  if [[ -f "$TARGET_MO" ]]; then
    mkdir -p "$BACKUP_DIR/locale/pl/LC_MESSAGES"
    cp -a "$TARGET_MO" "$BACKUP_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
  fi
  echo "Backup: $BACKUP_DIR"
fi

# Refuse to reuse a backup from a different extension build.
read -r backup_version backup_version_name < <(
  python3 - "$BACKUP_DIR/metadata.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("version", ""), data.get("version-name", ""))
PY
)
if [[ "$backup_version" != "$EXPECTED_VERSION" || "$backup_version_name" != "$EXPECTED_VERSION_NAME" ]]; then
  echo "FAIL: Spotlight localization backup does not match audited v14 / 2026.11" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/prefs"
for rel in "${files[@]}"; do
  cp -a "$BACKUP_DIR/$rel" "$tmp_dir/$rel"
done

patch_count=0
while IFS= read -r patch_file; do
  patch_count=$((patch_count + 1))
  patch_name="$(basename "$patch_file")"
  if ! patch --dry-run --batch --forward -p1 -d "$tmp_dir" < "$patch_file" >/dev/null; then
    echo "FAIL: Spotlight localization patch does not apply cleanly: $patch_name" >&2
    exit 1
  fi
  if ! patch --batch --forward -p1 -d "$tmp_dir" < "$patch_file" >/dev/null; then
    echo "FAIL: Spotlight localization patch failed: $patch_name" >&2
    exit 1
  fi
  echo "Applied: $patch_name"
done < <(find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | sort)

if [[ "$patch_count" -ne 4 ]]; then
  echo "FAIL: expected 4 Spotlight localization patches, found $patch_count" >&2
  exit 1
fi

python3 - "$tmp_dir/metadata.json" "$DOMAIN" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
domain = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))
data["gettext-domain"] = domain
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

msgfmt --check "$SOURCE_PO" -o "$tmp_dir/$DOMAIN.mo"

mkdir -p "$LOCALE_DIR"
for rel in "${files[@]}"; do
  install -D -m 0644 "$tmp_dir/$rel" "$EXT_DIR/$rel"
done
install -m 0644 "$tmp_dir/$DOMAIN.mo" "$TARGET_MO"

python3 - "$METADATA" "$EXPECTED_VERSION" "$EXPECTED_VERSION_NAME" "$DOMAIN" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
if str(data.get("version", "")) != sys.argv[2]:
    raise SystemExit("FAIL: installed Spotlight numeric version drift")
if str(data.get("version-name", "")) != sys.argv[3]:
    raise SystemExit("FAIL: installed Spotlight version-name drift")
if data.get("gettext-domain") != sys.argv[4]:
    raise SystemExit("FAIL: Spotlight gettext-domain patch not installed")
PY

cmp -s "$tmp_dir/$DOMAIN.mo" "$TARGET_MO" || {
  echo "FAIL: installed Spotlight Polish catalog differs from repository build" >&2
  exit 1
}

echo "PASS: Spotlight v14 / 2026.11 Polish localization installed"
echo "Log out and back in before visually validating Spotlight preferences."
