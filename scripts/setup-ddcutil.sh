#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v ddcutil >/dev/null 2>&1; then
  echo "ERROR: ddcutil is not installed." >&2
  exit 1
fi

RULE="/usr/lib/udev/rules.d/60-ddcutil-i2c.rules"
if [[ ! -f "$RULE" ]]; then
  echo "ERROR: ddcutil udev rule is missing: $RULE" >&2
  exit 1
fi

echo "Reloading udev rules for DDC/CI access..."
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=i2c-dev

# Access is granted by the Fedora ddcutil package's uaccess rule through
# systemd-logind. Do not make /dev/i2c-* world-writable and do not hard-code
# a monitor-specific I2C bus number.
echo "ddcutil udev access initialized."
echo "External DDC/CI displays, when present, can be checked with: ddcutil detect"
