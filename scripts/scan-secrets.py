#!/usr/bin/env python3
"""High-confidence secret scanner for tracked repository content.

This intentionally favors low false-positive patterns. It complements .gitignore;
it does not replace a full history-aware scanner such as gitleaks.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (
        "private-key header",
        re.compile(r"-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----"),
    ),
    (
        "GitHub token",
        re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    ),
    (
        "GitHub fine-grained token",
        re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    ),
    (
        "AWS access key",
        re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    ),
    (
        "Slack token",
        re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    ),
    (
        "Google API key",
        re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    ),
]

FORBIDDEN_BASENAMES = {
    ".env",
    "id_rsa",
    "id_dsa",
    "id_ecdsa",
    "id_ed25519",
}
FORBIDDEN_SUFFIXES = {".p12", ".pfx"}


def repository_files() -> list[Path]:
    proc = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode == 0:
        files: list[Path] = []
        for raw in proc.stdout.split(b"\0"):
            if not raw:
                continue
            files.append(ROOT / raw.decode("utf-8", errors="strict"))
        return files

    # GitHub container jobs may expose the checked-out worktree without a usable
    # repository metadata mount. Scanning the complete checkout is fail-safe:
    # it is broader than tracked-file scanning, not narrower.
    print(
        "INFO: git metadata unavailable; scanning the complete checkout tree",
        file=sys.stderr,
    )
    files = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in {".git", "__pycache__"} for part in rel.parts):
            continue
        files.append(path)
    return files


def scan_path(path: Path) -> list[str]:
    rel = path.relative_to(ROOT)
    findings: list[str] = []

    if path.name in FORBIDDEN_BASENAMES or path.suffix.lower() in FORBIDDEN_SUFFIXES:
        findings.append(f"{rel}: tracked secret-like filename is not allowed")

    try:
        data = path.read_bytes()
    except OSError as exc:
        findings.append(f"{rel}: unable to read tracked file: {exc}")
        return findings

    if b"\0" in data:
        return findings

    text = data.decode("utf-8", errors="replace")
    for label, pattern in SECRET_PATTERNS:
        for match in pattern.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            findings.append(f"{rel}:{line}: possible {label}")
    return findings


def self_test() -> None:
    positives = [
        "-----BEGIN " + "OPENSSH PRIVATE KEY-----",
        "ghp_" + ("a" * 28),
        "github_pat_" + ("b" * 32),
        "AKIA" + ("A" * 16),
        "xoxb-" + ("1" * 24),
        "AIza" + ("c" * 35),
    ]
    for sample in positives:
        if not any(pattern.search(sample) for _, pattern in SECRET_PATTERNS):
            raise SystemExit("FAIL: secret scanner positive self-test missed a pattern")

    negatives = [
        "PasswordAuthentication=no",
        'SSH_KEY="$HOME/.ssh/id_ed25519"',
        "token authentication is intentionally not stored",
    ]
    for sample in negatives:
        if any(pattern.search(sample) for _, pattern in SECRET_PATTERNS):
            raise SystemExit(f"FAIL: secret scanner false positive in self-test: {sample}")

    print("PASS: secret scanner pattern self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()

    findings: list[str] = []
    for path in repository_files():
        findings.extend(scan_path(path))

    if findings:
        print("=== SECRET SCAN: FAIL ===", file=sys.stderr)
        for finding in findings:
            print(f"FAIL: {finding}", file=sys.stderr)
        return 1

    print("=== SECRET SCAN: PASS ===")
    print("PASS: no high-confidence secrets found in tracked repository files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
