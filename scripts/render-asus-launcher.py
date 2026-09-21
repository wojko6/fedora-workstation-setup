#!/usr/bin/env python3
"""Safely parse and render the private ASUS SSH launcher configuration.

The config deliberately supports only a tiny KEY=value data format. It is never
executed as shell code.
"""

from __future__ import annotations

import argparse
import ipaddress
import re
import shlex
import sys
from pathlib import Path

ALLOWED_KEYS = ("SSH_KEY", "SSH_PORT", "SSH_USER", "ROUTER_HOST")
PLACEHOLDERS = {
    "SSH_KEY": "__SSH_KEY__",
    "SSH_PORT": "__SSH_PORT__",
    "SSH_USER": "__SSH_USER__",
    "ROUTER_HOST": "__ROUTER_HOST__",
}
ASSIGNMENT_RE = re.compile(r"^([A-Z][A-Z0-9_]*)\s*=\s*(.*?)\s*$")
SAFE_PATH_RE = re.compile(r"^[A-Za-z0-9_./@+:-]+$")
SAFE_USER_RE = re.compile(r"^[A-Za-z0-9._-]+$")
SAFE_HOST_LABEL_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")
UNRESOLVED_RE = re.compile(r"__[A-Z0-9_]+__")


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"ERROR: {message}")


def parse_scalar(raw: str, *, line_no: int) -> str:
    if not raw:
        fail(f"empty value on config line {line_no}")

    try:
        parts = shlex.split(raw, comments=False, posix=True)
    except ValueError as exc:
        fail(f"invalid quoting on config line {line_no}: {exc}")

    if len(parts) != 1:
        fail(
            f"config line {line_no} must contain exactly one scalar value; "
            "shell expressions and extra tokens are not allowed"
        )

    value = parts[0]
    if any(ch in value for ch in ("\x00", "\n", "\r")):
        fail(f"control character in config line {line_no}")
    return value


def parse_config(path: Path, home: Path) -> dict[str, str]:
    values: dict[str, str] = {}

    for line_no, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        match = ASSIGNMENT_RE.fullmatch(line)
        if not match:
            fail(f"invalid config syntax on line {line_no}: expected KEY=value")

        key, raw_value = match.groups()
        if key not in ALLOWED_KEYS:
            fail(f"unknown config key on line {line_no}: {key}")
        if key in values:
            fail(f"duplicate config key on line {line_no}: {key}")

        values[key] = parse_scalar(raw_value, line_no=line_no)

    missing = [key for key in ALLOWED_KEYS if key not in values]
    if missing:
        fail(f"missing required config key(s): {', '.join(missing)}")

    key_path = values["SSH_KEY"]
    if key_path == "$HOME":
        key_path = str(home)
    elif key_path.startswith("$HOME/"):
        key_path = str(home / key_path[len("$HOME/"):])
    elif key_path == "~":
        key_path = str(home)
    elif key_path.startswith("~/"):
        key_path = str(home / key_path[2:])

    if "$" in key_path or "`" in key_path:
        fail("SSH_KEY may only use the explicit $HOME or ~/ prefix")
    if not Path(key_path).is_absolute():
        fail("SSH_KEY must resolve to an absolute path")
    if not SAFE_PATH_RE.fullmatch(key_path):
        fail("SSH_KEY contains unsupported characters")
    values["SSH_KEY"] = key_path

    try:
        port = int(values["SSH_PORT"], 10)
    except ValueError:
        fail("SSH_PORT must be an integer")
    if not 1 <= port <= 65535:
        fail("SSH_PORT must be between 1 and 65535")
    values["SSH_PORT"] = str(port)

    if not SAFE_USER_RE.fullmatch(values["SSH_USER"]):
        fail("SSH_USER contains unsupported characters")

    host = values["ROUTER_HOST"]
    try:
        ipaddress.ip_address(host)
    except ValueError:
        if len(host) > 253:
            fail("ROUTER_HOST is too long")
        labels = host.rstrip(".").split(".")
        if not labels or any(not SAFE_HOST_LABEL_RE.fullmatch(label) for label in labels):
            fail("ROUTER_HOST must be a valid hostname or IP address")

    return values


def render_template(template_path: Path, values: dict[str, str], ddterm_bin: Path) -> str:
    template = template_path.read_text(encoding="utf-8")
    replacements = dict(values)
    replacements["DDTERM_BIN"] = str(ddterm_bin)

    if not ddterm_bin.is_absolute():
        fail("ddterm path must be absolute")
    if not SAFE_PATH_RE.fullmatch(str(ddterm_bin)):
        fail("ddterm path contains unsupported characters")

    rendered = template
    for key, placeholder in {
        "DDTERM_BIN": "__DDTERM_BIN__",
        **PLACEHOLDERS,
    }.items():
        count = rendered.count(placeholder)
        if count != 1:
            fail(f"template placeholder {placeholder} must occur exactly once, found {count}")
        rendered = rendered.replace(placeholder, replacements[key], 1)

    unresolved = UNRESOLVED_RE.findall(rendered)
    if unresolved:
        fail(f"unresolved launcher template placeholder(s): {', '.join(sorted(set(unresolved)))}")

    return rendered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--ddterm-bin", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--check-key-file", action="store_true")
    args = parser.parse_args()

    for path, label in ((args.config, "config"), (args.template, "template")):
        if not path.is_file():
            fail(f"ASUS launcher {label} file missing: {path}")

    values = parse_config(args.config, args.home)

    if args.check_key_file:
        key_path = Path(values["SSH_KEY"])
        if not key_path.is_file():
            fail(f"SSH private key file missing: {key_path}")

    rendered = render_template(args.template, values, args.ddterm_bin)
    args.output.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
