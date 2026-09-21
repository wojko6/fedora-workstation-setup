#!/usr/bin/env python3
"""Repository-level guard against accidentally tracked workstation secrets."""

from __future__ import annotations

import fnmatch
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FORBIDDEN_TRACKED = [
    ".env",
    "*.pem",
    "*.p12",
    "*.pfx",
    "id_rsa*",
    "id_ed25519*",
    "desktop/launchers/asus-router.conf",
    "gnome/weather-locations.local.tsv",
]

SECRET_PATTERNS = [
    ("OpenSSH private key", re.compile(r"-----BEGIN OPENSSH PRIVATE KEY-----")),
    ("generic private key", re.compile(r"-----BEGIN (?:RSA |EC |DSA )?PRIVATE KEY-----")),
    ("GitHub classic token", re.compile(r"\bghp_[A-Za-z0-9]{30,}\b")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{40,}\b")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
]

ALLOW_BINARY_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".mo", ".pak",
    ".pdf", ".zip", ".gz", ".xz", ".bz2", ".7z", ".rpm",
}


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return [p.decode("utf-8") for p in result.stdout.split(b"\0") if p]


def forbidden_path(path: str) -> str | None:
    name = Path(path).name
    for pattern in FORBIDDEN_TRACKED:
        if "/" in pattern:
            if fnmatch.fnmatch(path, pattern):
                return pattern
        elif fnmatch.fnmatch(name, pattern):
            return pattern
    return None


errors: list[str] = []
for rel in tracked_files():
    matched = forbidden_path(rel)
    if matched:
        errors.append(f"tracked sensitive path matches {matched!r}: {rel}")

    path = ROOT / rel
    if not path.is_file() or path.suffix.lower() in ALLOW_BINARY_SUFFIXES:
        continue

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    for label, pattern in SECRET_PATTERNS:
        if pattern.search(text):
            errors.append(f"{label} marker detected in tracked file: {rel}")

if errors:
    print("=== SECRET HYGIENE: FAIL ===")
    for error in errors:
        print(f"FAIL: {error}")
    raise SystemExit(1)

print("PASS: no forbidden private-state paths are tracked")
print("PASS: no high-confidence secret markers found in tracked text files")
print("=== SECRET HYGIENE: PASS ===")
