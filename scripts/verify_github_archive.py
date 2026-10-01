#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import tarfile
from pathlib import Path, PurePosixPath


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


parser = argparse.ArgumentParser(
    description=(
        "Verify a pinned GitHub source archive before extraction. "
        "Checks SHA-256 and basic archive path/root invariants."
    )
)
parser.add_argument("--archive", required=True)
parser.add_argument("--sha256", required=True)
parser.add_argument("--repo-name", required=True)
parser.add_argument("--commit", required=True)
args = parser.parse_args()

archive = Path(args.archive)
expected_sha256 = args.sha256.strip().lower()
repo_name = args.repo_name.strip()
commit = args.commit.strip().lower()

if not archive.is_file():
    fail(f"archive missing: {archive}")

if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
    fail("expected SHA-256 must be exactly 64 lowercase hexadecimal characters")

if not re.fullmatch(r"[0-9a-f]{40}", commit):
    fail("GitHub commit must be exactly 40 hexadecimal characters")

if not re.fullmatch(r"[A-Za-z0-9._-]+", repo_name):
    fail(f"unsafe repository name: {repo_name!r}")

actual_sha256 = hashlib.sha256(archive.read_bytes()).hexdigest()
if actual_sha256 != expected_sha256:
    fail(
        "SHA-256 mismatch: "
        f"expected {expected_sha256}, got {actual_sha256}"
    )

expected_root = f"{repo_name}-{commit}"
metadata_path = f"{expected_root}/metadata.json"

try:
    with tarfile.open(archive, mode="r:gz") as tf:
        members = tf.getmembers()
except (tarfile.TarError, OSError) as exc:
    fail(f"invalid gzip tar archive: {exc}")

if not members:
    fail("GitHub archive is empty")

metadata_present = False
for member in members:
    name = member.name
    path = PurePosixPath(name)

    if path.is_absolute() or ".." in path.parts:
        fail(f"unsafe archive member path: {name!r}")

    if not path.parts or path.parts[0] != expected_root:
        fail(
            "archive root mismatch: "
            f"expected {expected_root!r}, found member {name!r}"
        )

    if name.rstrip("/") == metadata_path:
        metadata_present = True

    if member.issym() or member.islnk():
        target = PurePosixPath(member.linkname)
        if target.is_absolute() or ".." in target.parts:
            fail(f"unsafe archive link target: {member.linkname!r}")

if not metadata_present:
    fail(f"required metadata missing from archive: {metadata_path}")

print(f"PASS: GitHub archive SHA-256 verified: {actual_sha256}")
print(f"PASS: GitHub archive root verified: {expected_root}")
print(f"PASS: GitHub archive metadata present: {metadata_path}")
