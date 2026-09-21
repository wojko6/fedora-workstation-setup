#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required=(bash python3 msgfmt shellcheck git patch)
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
echo "=== PATCH SYNTAX ==="
while IFS= read -r -d '' file; do
  echo "git apply --numstat $file"
  git apply --numstat "$file" >/dev/null
done < <(find patches -type f -name '*.patch' -print0)

echo
echo "=== HELIUM DATAPACK FIXTURES ==="
python3 scripts/helium_datapack.py self-test
python3 scripts/helium_datapack.py validate-overlay \
  --overlay localization/helium/v0.17.2.1-pl-completion.json

echo
echo "=== SECRET HYGIENE ==="
python3 scripts/test_secret_hygiene.py

echo
echo "=== REPOSITORY CONSISTENCY ==="
python3 scripts/validate-repository.py

echo
echo "=== EXTENSION SECURITY FIXTURES ==="
python3 scripts/test_extension_security.py

echo
echo "=== EXTENSION TREE INTEGRITY FIXTURES ==="
python3 scripts/test_extension_tree_integrity.py

echo
echo "=== INSTALLER PREFLIGHT FIXTURES ==="
python3 scripts/test_install_preflight.py

echo
echo "=== ASUS LAUNCHER CONFIG FIXTURES ==="
python3 scripts/test_asus_launcher_config.py

echo
echo "=== DING SYSTEM MONITOR FIXTURES ==="
python3 scripts/test_ding_system_monitor_menu.py

echo
echo "=== GITHUB METADATA SECURITY FIXTURES ==="
python3 scripts/test_github_metadata_security.py

echo
echo "=== FIREWALL POLICY SECURITY FIXTURES ==="
python3 scripts/test_firewall_policy.py

echo
echo "=== SECURITY POSTURE / FAIL-CLOSED FIXTURES ==="
python3 scripts/test_verify_security_posture.py

echo
echo "=== STATIC CHECKS: PASS ==="
