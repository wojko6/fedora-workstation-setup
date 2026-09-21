#!/usr/bin/env python3
"""Safely render the local ASUS SSH launcher without executing its config."""

from __future__ import annotations

import argparse
import ipaddress
import os
import re
import shlex
import stat
from pathlib import Path

ALLOWED_KEYS = {"SSH_KEY", "SSH_PORT", "SSH_USER", "ROUTER_HOST"}
USER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]{0,63}$")
HOST_RE = re.compile(
    r"^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(?:\.(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*\.?$"
)


class ConfigError(ValueError):
    pass


def parse_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}

    for lineno, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ConfigError(f"{path}:{lineno}: expected KEY=VALUE")

        key, raw_value = line.split("=", 1)
        key = key.strip()
        raw_value = raw_value.strip()

        if key not in ALLOWED_KEYS:
            raise ConfigError(f"{path}:{lineno}: unknown key: {key}")
        if key in values:
            raise ConfigError(f"{path}:{lineno}: duplicate key: {key}")

        try:
            parsed = shlex.split(raw_value, posix=True)
        except ValueError as exc:
            raise ConfigError(f"{path}:{lineno}: invalid quoting: {exc}") from exc

        if len(parsed) != 1:
            raise ConfigError(f"{path}:{lineno}: value must be exactly one token")

        value = parsed[0]
        value = value.replace("${HOME}", str(Path.home())).replace("$HOME", str(Path.home()))
        if "$" in value or "`" in value:
            raise ConfigError(
                f"{path}:{lineno}: shell expansion syntax is not allowed; only $HOME is supported"
            )
        if any(ord(ch) < 32 or ord(ch) == 127 for ch in value):
            raise ConfigError(f"{path}:{lineno}: control characters are not allowed")
        values[key] = value

    missing = ALLOWED_KEYS - values.keys()
    if missing:
        raise ConfigError(f"{path}: missing required keys: {', '.join(sorted(missing))}")

    return values


def validate(values: dict[str, str]) -> dict[str, str]:
    try:
        port = int(values["SSH_PORT"], 10)
    except ValueError as exc:
        raise ConfigError("SSH_PORT must be an integer") from exc
    if not 1 <= port <= 65535:
        raise ConfigError("SSH_PORT must be in range 1..65535")

    user = values["SSH_USER"]
    if not USER_RE.fullmatch(user):
        raise ConfigError("SSH_USER contains unsupported characters")

    host = values["ROUTER_HOST"]
    try:
        ipaddress.ip_address(host)
    except ValueError:
        if not HOST_RE.fullmatch(host):
            raise ConfigError("ROUTER_HOST must be an IP address or DNS hostname")

    key = Path(values["SSH_KEY"]).expanduser()
    if not key.is_absolute():
        raise ConfigError("SSH_KEY must resolve to an absolute path")
    if not key.is_file():
        raise ConfigError(f"SSH_KEY does not exist or is not a regular file: {key}")

    mode = stat.S_IMODE(key.stat().st_mode)
    if mode & 0o077:
        raise ConfigError(
            f"SSH_KEY permissions are too broad ({mode:04o}); expected no group/other access"
        )

    return {
        "SSH_KEY": str(key),
        "SSH_PORT": str(port),
        "SSH_USER": user,
        "ROUTER_HOST": host,
    }


def desktop_quote(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_@%+=:,./-]+", value):
        return value
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("`", "\\`")
        .replace("$", "\\$")
    )
    return f'"{escaped}"'


def render(template: str, values: dict[str, str], ddterm_bin: Path) -> str:
    if not ddterm_bin.is_absolute():
        raise ConfigError("ddterm path must be absolute")
    if not ddterm_bin.is_file() or not os.access(ddterm_bin, os.X_OK):
        raise ConfigError(f"ddterm command not found or not executable: {ddterm_bin}")

    replacements = {
        "__DDTERM_BIN__": desktop_quote(str(ddterm_bin)),
        "__SSH_KEY__": desktop_quote(values["SSH_KEY"]),
        "__SSH_PORT__": values["SSH_PORT"],
        "__SSH_USER__": values["SSH_USER"],
        "__ROUTER_HOST__": desktop_quote(values["ROUTER_HOST"]),
    }

    output = template
    for marker, value in replacements.items():
        if output.count(marker) != 1:
            raise ConfigError(f"template marker must occur exactly once: {marker}")
        output = output.replace(marker, value)

    if "__" in output:
        unresolved = sorted(set(re.findall(r"__[A-Z0-9_]+__", output)))
        if unresolved:
            raise ConfigError(f"unresolved template markers: {', '.join(unresolved)}")

    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--ddterm-bin", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        values = validate(parse_config(args.config))
        template = args.template.read_text(encoding="utf-8")
        output = render(template, values, args.ddterm_bin)
    except (OSError, ConfigError) as exc:
        raise SystemExit(f"ERROR: {exc}") from exc

    args.output.write_text(output, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
