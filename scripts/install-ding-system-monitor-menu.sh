#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "INFO: DING System Monitor customization is now delivered by the managed-system DING v99 tree."
exec bash "$ROOT_DIR/scripts/install-ding-managed-system.sh"
