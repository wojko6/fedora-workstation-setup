#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "system" / "syslog-ng-tailscale-readiness.sh"
INSTALLER = ROOT / "install.sh"
VERIFIER = ROOT / "scripts" / "verify.sh"

helper = HELPER.read_text(encoding="utf-8")
installer = INSTALLER.read_text(encoding="utf-8")
verifier = VERIFIER.read_text(encoding="utf-8")

helper_contracts = [
    '/etc/syslog-ng/conf.d/asus-edge-collector.conf',
    '/etc/systemd/system/syslog-ng.service.d',
    '20-asus-edge-tailscale.conf',
    'tailscale wait --timeout=10s',
    'wait --timeout=60s',
    'ip --assert=$ts_ip',
    'RestartSec=15s',
    'systemd-analyze verify syslog-ng.service',
    'systemctl restart syslog-ng.service',
    'COLLECTOR_PORT="\${SYSLOG_NG_COLLECTOR_PORT:-6514}"',
]

for phrase in helper_contracts:
    if phrase not in helper:
        raise SystemExit(f"FAIL: syslog-ng readiness helper contract missing: {phrase}")

if re.search(r"\b100\.(?:\d{1,3}\.){2}\d{1,3}\b", helper):
    raise SystemExit("FAIL: deployment-specific Tailscale IPv4 address leaked into readiness helper")

if "system/syslog-ng-tailscale-readiness.sh" not in installer:
    raise SystemExit("FAIL: top-level installer does not include syslog-ng readiness stage")

verifier_contracts = [
    "=== SYSLOG-NG TAILSCALE COLLECTOR ===",
    '/etc/syslog-ng/conf.d/asus-edge-collector.conf',
    '20-asus-edge-tailscale.conf',
    'wait --timeout=60s',
    'ip --assert=$ts_ip',
    "Cannot assign requested address",
    "Error binding socket",
]

for phrase in verifier_contracts:
    if phrase not in verifier:
        raise SystemExit(f"FAIL: live verifier syslog-ng readiness contract missing: {phrase}")

print("PASS: syslog-ng Tailscale readiness helper contracts present")
print("PASS: no deployment-specific Tailscale IPv4 address is committed")
print("PASS: installer and live verifier include the readiness integration")
print("=== SYSLOG-NG TAILSCALE READINESS FIXTURES: PASS ===")
