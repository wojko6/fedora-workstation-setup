#!/usr/bin/env python3
"""High-confidence secret scanner for current content and full Git history.

The scanner intentionally favors low false-positive patterns. The default mode
checks the current tracked checkout. --history additionally provides a
history-aware gate by examining every reachable historical Git blob and
secret-like filename. It reports locations and secret classes, never matched
secret values.
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


def git_run(
    args: list[str],
    *,
    text: bool = True,
    input_data: str | None = None,
) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        input=input_data,
        text=text,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def repository_files() -> list[Path]:
    proc = git_run(["ls-files", "-z"], text=False)
    if proc.returncode == 0:
        files: list[Path] = []
        for raw in proc.stdout.split(b"\0"):
            if not raw:
                continue
            files.append(ROOT / raw.decode("utf-8", errors="strict"))
        return files

    # GitHub container jobs may expose the checked-out worktree without a usable
    # repository metadata mount. Scanning the complete checkout is fail-safe for
    # current content: it is broader than tracked-file scanning, not narrower.
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


def secret_like_filename(path_text: str) -> bool:
    name = Path(path_text).name
    suffix = Path(path_text).suffix.lower()
    return name in FORBIDDEN_BASENAMES or suffix in FORBIDDEN_SUFFIXES


def scan_text(text: str, location: str) -> list[str]:
    findings: list[str] = []
    for label, pattern in SECRET_PATTERNS:
        for match in pattern.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            findings.append(f"{location}:{line}: possible {label}")
    return findings


def scan_bytes(data: bytes, location: str) -> list[str]:
    if b"\0" in data:
        return []
    text = data.decode("utf-8", errors="replace")
    return scan_text(text, location)


def scan_path(path: Path) -> list[str]:
    rel = path.relative_to(ROOT)
    findings: list[str] = []

    if secret_like_filename(str(rel)):
        findings.append(f"{rel}: tracked secret-like filename is not allowed")

    try:
        data = path.read_bytes()
    except OSError as exc:
        findings.append(f"{rel}: unable to read tracked file: {exc}")
        return findings

    findings.extend(scan_bytes(data, str(rel)))
    return findings


def require_complete_history() -> None:
    inside = git_run(["rev-parse", "--is-inside-work-tree"])
    if inside.returncode != 0 or inside.stdout.strip() != "true":
        raise RuntimeError("Git repository metadata unavailable for history scan")

    shallow = git_run(["rev-parse", "--is-shallow-repository"])
    if shallow.returncode != 0:
        raise RuntimeError(
            "unable to determine whether repository history is complete: "
            + (shallow.stderr.strip() or "no diagnostic")
        )
    if shallow.stdout.strip() != "false":
        raise RuntimeError(
            "history scan requires a complete clone; shallow repository detected"
        )


def historical_objects() -> list[tuple[str, str]]:
    proc = git_run(["rev-list", "--objects", "--all"])
    if proc.returncode != 0:
        raise RuntimeError(
            "unable to enumerate Git history: "
            + (proc.stderr.strip() or "no diagnostic")
        )

    objects: list[tuple[str, str]] = []
    for raw in proc.stdout.splitlines():
        object_id, sep, path = raw.partition(" ")
        if sep and object_id and path:
            objects.append((object_id, path))
    return objects


def blob_types(object_ids: list[str]) -> dict[str, str]:
    if not object_ids:
        return {}

    proc = git_run(
        ["cat-file", "--batch-check=%(objectname) %(objecttype)"],
        input_data="\n".join(object_ids) + "\n",
    )
    if proc.returncode != 0:
        raise RuntimeError(
            "unable to classify Git history objects: "
            + (proc.stderr.strip() or "no diagnostic")
        )

    result: dict[str, str] = {}
    for raw in proc.stdout.splitlines():
        object_id, sep, object_type = raw.partition(" ")
        if sep:
            result[object_id] = object_type.strip()
    return result


def read_blob(object_id: str) -> bytes:
    proc = git_run(["cat-file", "blob", object_id], text=False)
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"unable to read historical blob {object_id[:12]}: "
            f"{stderr or 'no diagnostic'}"
        )
    return proc.stdout


def scan_history() -> tuple[list[str], int]:
    require_complete_history()

    objects = historical_objects()
    object_type = blob_types([object_id for object_id, _ in objects])
    findings: list[str] = []
    seen_blobs: set[str] = set()
    scanned_blobs = 0

    for object_id, path in objects:
        location = f"history:{object_id[:12]}:{path}"

        if secret_like_filename(path):
            findings.append(
                f"{location}: historical secret-like filename is not allowed"
            )

        if object_type.get(object_id) != "blob" or object_id in seen_blobs:
            continue

        seen_blobs.add(object_id)
        data = read_blob(object_id)
        scanned_blobs += 1
        findings.extend(scan_bytes(data, location))

    return findings, scanned_blobs


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


def report(findings: list[str], *, history: bool, scanned_blobs: int = 0) -> int:
    label = "HISTORY SECRET SCAN" if history else "SECRET SCAN"
    if findings:
        print(f"=== {label}: FAIL ===", file=sys.stderr)
        for finding in findings:
            print(f"FAIL: {finding}", file=sys.stderr)
        return 1

    print(f"=== {label}: PASS ===")
    if history:
        print(
            "PASS: no high-confidence secrets found in complete reachable Git history "
            f"({scanned_blobs} unique blobs scanned)"
        )
    else:
        print("PASS: no high-confidence secrets found in tracked repository files")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument(
        "--history",
        action="store_true",
        help="scan every reachable historical Git blob; requires a non-shallow clone",
    )
    args = parser.parse_args()

    if args.self_test:
        self_test()

    if args.history:
        try:
            findings, scanned_blobs = scan_history()
        except RuntimeError as exc:
            print(f"=== HISTORY SECRET SCAN: FAIL ===", file=sys.stderr)
            print(f"FAIL: {exc}", file=sys.stderr)
            return 1
        return report(findings, history=True, scanned_blobs=scanned_blobs)

    findings: list[str] = []
    for path in repository_files():
        findings.extend(scan_path(path))
    return report(findings, history=False)


if __name__ == "__main__":
    sys.exit(main())
