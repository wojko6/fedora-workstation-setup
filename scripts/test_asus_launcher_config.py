#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RENDERER = ROOT / "scripts" / "render_asus_launcher.py"
TEMPLATE = ROOT / "desktop" / "launchers" / "asus-router.desktop.template"
INSTALLER = ROOT / "scripts" / "install-launchers.sh"


def run_renderer(root: Path, config_text: str):
    home = root / "home"
    home.mkdir(exist_ok=True)
    ssh = home / ".ssh"
    ssh.mkdir(exist_ok=True)
    key = ssh / "id_ed25519"
    key.write_text("fixture private key\n", encoding="utf-8")
    key.chmod(0o600)

    ddterm = root / "ddterm"
    ddterm.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    ddterm.chmod(0o700)

    config = root / "asus-router.conf"
    config.write_text(config_text.replace("__HOME__", str(home)), encoding="utf-8")
    output = root / "asus-router.desktop"

    env = os.environ.copy()
    env["HOME"] = str(home)
    result = subprocess.run(
        [
            "python3",
            str(RENDERER),
            "--config",
            str(config),
            "--template",
            str(TEMPLATE),
            "--ddterm-bin",
            str(ddterm),
            "--output",
            str(output),
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )
    return result, output


with tempfile.TemporaryDirectory(prefix="asus-launcher-tests-") as td:
    root = Path(td)

    result, output = run_renderer(
        root,
        """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="1122"
SSH_USER="admin1"
ROUTER_HOST="192.168.50.1"
""",
    )
    if result.returncode != 0:
        raise SystemExit(f"FAIL: valid ASUS launcher config rejected: {result.stderr}")
    text = output.read_text(encoding="utf-8")
    for expected in [
        "-o PasswordAuthentication=no",
        "-p 1122",
        "admin1@192.168.50.1",
        ".ssh/id_ed25519",
    ]:
        if expected not in text:
            raise SystemExit(f"FAIL: rendered launcher missing {expected!r}")
    print("PASS: valid ASUS launcher config rendered")

    marker = root / "pwned"
    result, _ = run_renderer(
        root,
        f"""SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="1122"
SSH_USER="admin1"
ROUTER_HOST="$(touch{marker})"
""",
    )
    if result.returncode == 0:
        raise SystemExit("FAIL: shell-expression config unexpectedly accepted")
    if marker.exists():
        raise SystemExit("FAIL: launcher config executed shell code")
    print("PASS: shell-expression config rejected without execution")

    result, _ = run_renderer(
        root,
        """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="70000"
SSH_USER="admin1"
ROUTER_HOST="192.168.50.1"
""",
    )
    if result.returncode == 0 or "1..65535" not in result.stderr:
        raise SystemExit("FAIL: invalid SSH port not rejected")
    print("PASS: invalid SSH port rejected")

    result, _ = run_renderer(
        root,
        """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="1122"
SSH_USER="bad user"
ROUTER_HOST="192.168.50.1"
""",
    )
    if result.returncode == 0:
        raise SystemExit("FAIL: invalid SSH user not rejected")
    print("PASS: invalid SSH user rejected")

    result, _ = run_renderer(
        root,
        """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="1122"
SSH_USER="admin1"
ROUTER_HOST="192.168.50.1"
EXTRA="unexpected"
""",
    )
    if result.returncode == 0 or "unknown key" not in result.stderr:
        raise SystemExit("FAIL: unknown ASUS config key not rejected")
    print("PASS: unknown config key rejected")

installer_text = INSTALLER.read_text(encoding="utf-8")
for required in [
    "render_asus_launcher.py",
    "--config",
    "--template",
    "--ddterm-bin",
    "--output",
]:
    if required not in installer_text:
        raise SystemExit(f"FAIL: launcher installer contract missing: {required}")

if 'source "$ASUS_CONF"' in installer_text:
    raise SystemExit("FAIL: launcher installer still executes local config with source")

print("PASS: install-launchers uses data parser instead of shell source")
print("=== ASUS LAUNCHER CONFIG TESTS: PASS ===")
