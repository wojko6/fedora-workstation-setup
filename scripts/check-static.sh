#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required=(bash python3 msgfmt shellcheck)
for cmd in "${required[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required validation tool is missing: $cmd" >&2
    exit 1
  }
done

echo "=== SHELL SYNTAX ==="
while IFS= read -r -d '' file; do
  echo "bash -n $file"
  bash -n "$file"
done < <(find . -type f -name '*.sh' -not -path './.git/*' -print0)

echo
echo "=== SHELLCHECK (ERROR LEVEL) ==="
while IFS= read -r -d '' file; do
  echo "shellcheck $file"
  shellcheck --severity=error "$file"
done < <(find . -type f -name '*.sh' -not -path './.git/*' -print0)

echo
echo "=== PYTHON SYNTAX ==="
while IFS= read -r -d '' file; do
  echo "compile $file"
  python3 - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
compile(source, str(path), "exec")
PY
done < <(find . -type f -name '*.py' -not -path './.git/*' -print0)

echo
echo "=== GETTEXT CATALOGS ==="
while IFS= read -r -d '' file; do
  echo "msgfmt --check $file"
  msgfmt --check "$file" -o /dev/null
done < <(find localization -type f -name '*.po' -print0)

echo
echo "=== JSON FILES ==="
while IFS= read -r -d '' file; do
  echo "json.tool $file"
  python3 -m json.tool "$file" >/dev/null
done < <(find . -type f -name '*.json' -not -path './.git/*' -print0)

echo
echo "=== REPOSITORY CONSISTENCY ==="
python3 scripts/validate-repository.py

echo
echo "=== STATIC CHECKS: PASS ==="
