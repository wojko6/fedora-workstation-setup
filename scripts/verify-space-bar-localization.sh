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
    echo "FAIL: missing Space Bar localization mapping" >&2
    exit 1
}
[[ -f "$APPLY_SCRIPT" ]] || {
    echo "FAIL: missing Space Bar localization helper" >&2
    exit 1
}
[[ -d "$BACKUP_DIR" ]] || {
    echo "FAIL: missing pristine Space Bar v39 localization backup" >&2
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

translated_patterns="$(python3 - "$MAPPING" <<'PY'
import json
import sys
from pathlib import Path

mapping = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(sum(len(spec["replacements"]) for spec in mapping["files"].values()))
PY
)"

if [[ "$translated_patterns" != "109" ]]; then
    echo "FAIL: unexpected Space Bar translation pattern count: $translated_patterns" >&2
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
expected_dir="$tmp_dir/expected"

python3 "$APPLY_SCRIPT" \
    --mapping "$MAPPING" \
    --source-root "$BACKUP_DIR" \
    --dest-root "$expected_dir"

for relative in "${files[@]}"; do
    if [[ ! -f "$EXT_DIR/$relative" ]]; then
        echo "FAIL: missing installed Space Bar localization target: $relative" >&2
        exit 1
    fi
    if ! cmp -s "$expected_dir/$relative" "$EXT_DIR/$relative"; then
        echo "FAIL: Space Bar Polish localization differs: $relative" >&2
        exit 1
    fi
done

echo "Translated patterns: $translated_patterns"
echo "PASS: Space Bar v39 Polish localization matches repository"
