#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RENDERER = ROOT / "scripts" / "render-asus-launcher.py"
TEMPLATE = ROOT / "desktop" / "launchers" / "asus-router.desktop.template"
EXAMPLE = ROOT / "desktop" / "launchers" / "asus-router.conf.example"


def run_renderer(config: Path, output: Path, *, expect: int) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        [
            "python3",
            str(RENDERER),
            "--config",
            str(config),
            "--template",
            str(TEMPLATE),
            "--ddterm-bin",
            "/home/tester/.local/share/gnome-shell/extensions/ddterm@amezin.github.com/bin/com.github.amezin.ddterm",
            "--home",
            "/home/tester",
            "--output",
            str(output),
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != expect:
        raise SystemExit(
            f"FAIL: renderer returned {proc.returncode}, expected {expect}\n"
            f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        )
    return proc


with tempfile.TemporaryDirectory(prefix="asus-launcher-test-") as td:
    temp = Path(td)
    output = temp / "asus-router.desktop"

    run_renderer(EXAMPLE, output, expect=0)
    rendered = output.read_text(encoding="utf-8")

    required = [
        "/home/tester/.ssh/id_ed25519",
        "-p 2222",
        "router-admin@192.168.1.1",
        "PasswordAuthentication=no",
    ]
    for phrase in required:
        if phrase not in rendered:
            raise SystemExit(f"FAIL: rendered ASUS launcher missing expected text: {phrase}")
    if "__" in rendered:
        raise SystemExit("FAIL: rendered ASUS launcher contains unresolved placeholders")

    print("PASS: ASUS launcher example parses and renders without shell evaluation")

    bad_cases = {
        "unknown key": """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="2222"
SSH_USER="router-admin"
ROUTER_HOST="192.168.1.1"
RUN_ME="$(touch /tmp/should-not-run)"
""",
        "command substitution": """SSH_KEY="$(touch /tmp/should-not-run)"
SSH_PORT="2222"
SSH_USER="router-admin"
ROUTER_HOST="192.168.1.1"
""",
        "invalid port": """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="70000"
SSH_USER="router-admin"
ROUTER_HOST="192.168.1.1"
""",
        "duplicate key": """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="2222"
SSH_PORT="2223"
SSH_USER="router-admin"
ROUTER_HOST="192.168.1.1"
""",
        "host injection": """SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PORT="2222"
SSH_USER="router-admin"
ROUTER_HOST="192.168.1.1;touch"
""",
    }

    marker = Path("/tmp/should-not-run")
    marker.unlink(missing_ok=True)

    for name, text in bad_cases.items():
        config = temp / f"{name.replace(' ', '-')}.conf"
        config.write_text(text, encoding="utf-8")
        proc = run_renderer(config, output, expect=1)
        if "ERROR:" not in proc.stderr:
            raise SystemExit(f"FAIL: invalid case did not emit an ERROR: {name}")
        print(f"PASS: rejected unsafe ASUS launcher config: {name}")

    if marker.exists():
        marker.unlink()
        raise SystemExit("FAIL: ASUS config parser executed shell content")

print("PASS: ASUS launcher config is treated strictly as data")
