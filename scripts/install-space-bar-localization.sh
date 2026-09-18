#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="space-bar@luchrioh"
EXPECTED_VERSION="39"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
MAPPING="$ROOT_DIR/localization/space-bar/v39-replacements.json"
APPLY_SCRIPT="$ROOT_DIR/scripts/apply-space-bar-localization.py"
BACKUP_DIR="$EXT_DIR/.localization-backup-v39"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: Space Bar extension not installed"
    exit 0
fi

for cmd in python3 sha256sum gnome-extensions; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

[[ -f "$MAPPING" ]] || {
    echo "FAIL: missing Space Bar localization mapping: $MAPPING" >&2
    exit 1
}
[[ -f "$APPLY_SCRIPT" ]] || {
    echo "FAIL: missing Space Bar localization helper: $APPLY_SCRIPT" >&2
    exit 1
}

version="$(
    gnome-extensions info "$UUID" 2>/dev/null |
        sed -nE 's/^[[:space:]]*(Version|Wersja):[[:space:]]*//p' |
        head -n 1
)"
if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Space Bar localization is pinned to v39; installed version is ${version:-unknown}" >&2
    exit 1
fi

expected_metadata_sha="$(python3 - "$MAPPING" <<'PY'
import json
import sys
from pathlib import Path

mapping = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(mapping["metadata_sha256"])
PY
)"
actual_metadata_sha="$(sha256sum "$EXT_DIR/metadata.json" | awk '{print $1}')"
if [[ "$actual_metadata_sha" != "$expected_metadata_sha" ]]; then
    echo "FAIL: Space Bar v39 metadata fingerprint differs from the audited package" >&2
    echo "expected: $expected_metadata_sha" >&2
    echo "actual:   $actual_metadata_sha" >&2
    exit 1
fi

mapfile -t files < <(python3 - "$MAPPING" <<'PY'
import json
import sys
from pathlib import Path

mapping = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for path in mapping["files"]:
    print(path)
PY
)

if ((${#files[@]} == 0)); then
    echo "FAIL: Space Bar localization mapping contains no files" >&2
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
expected_dir="$tmp_dir/expected"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Validating pristine Space Bar v39 files..."
    python3 "$APPLY_SCRIPT" \
        --mapping "$MAPPING" \
        --source-root "$EXT_DIR" \
        --dest-root "$expected_dir"

    echo "Creating version-specific pristine backup..."
    for relative in "${files[@]}"; do
        mkdir -p "$BACKUP_DIR/$(dirname -- "$relative")"
        cp -a "$EXT_DIR/$relative" "$BACKUP_DIR/$relative"
    done
    echo "Backup: $BACKUP_DIR"
else
    echo "Validating saved pristine Space Bar v39 backup..."
    python3 "$APPLY_SCRIPT" \
        --mapping "$MAPPING" \
        --source-root "$BACKUP_DIR" \
        --dest-root "$expected_dir"
fi

# Never overwrite an unknown same-version build. Live files must be either the
# audited pristine v39 files or the exact repository-localized result.
for relative in "${files[@]}"; do
    pristine_sha="$(python3 - "$MAPPING" "$relative" <<'PY'
import json
import sys
from pathlib import Path

mapping = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(mapping["files"][sys.argv[2]]["sha256"])
PY
)"
    live_sha="$(sha256sum "$EXT_DIR/$relative" | awk '{print $1}')"
    if [[ "$live_sha" != "$pristine_sha" ]] && ! cmp -s "$EXT_DIR/$relative" "$expected_dir/$relative"; then
        echo "FAIL: refusing to overwrite unexpected Space Bar v39 file: $relative" >&2
        exit 1
    fi
done

for relative in "${files[@]}"; do
    install -D -m 0644 "$expected_dir/$relative" "$EXT_DIR/$relative"
done

for relative in "${files[@]}"; do
    if ! cmp -s "$expected_dir/$relative" "$EXT_DIR/$relative"; then
        echo "FAIL: installed Space Bar localization differs: $relative" >&2
        exit 1
    fi
done

echo "PASS: Space Bar v39 Polish localization installed"
echo "Sign out and back in before validating the runtime panel menu translation."
