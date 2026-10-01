#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import io
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFIER = ROOT / "scripts" / "verify_github_archive.py"
INSTALLER = ROOT / "scripts" / "install-extensions.sh"
REPOSITORY_VALIDATOR = ROOT / "scripts" / "validate-repository.py"

REPO_NAME = "dhruva"
COMMIT = "f8121f68fcef48c0324e8cd87fd30bf9a2131962"
ARCHIVE_ROOT = f"{REPO_NAME}-{COMMIT}"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def create_archive(path: Path, *, root: str = ARCHIVE_ROOT, unsafe: bool = False) -> None:
    with tarfile.open(path, "w:gz") as tf:
        metadata = b'{"uuid":"dhruva@narkagni"}\n'
        info = tarfile.TarInfo(f"{root}/metadata.json")
        info.size = len(metadata)
        tf.addfile(info, io.BytesIO(metadata))

        source = b"// fixture\n"
        source_info = tarfile.TarInfo(f"{root}/extension.js")
        source_info.size = len(source)
        tf.addfile(source_info, io.BytesIO(source))

        if unsafe:
            unsafe_data = b"nope\n"
            unsafe_info = tarfile.TarInfo("../escape")
            unsafe_info.size = len(unsafe_data)
            tf.addfile(unsafe_info, io.BytesIO(unsafe_data))


def run_verifier(path: Path, sha256: str):
    return subprocess.run(
        [
            sys.executable,
            str(VERIFIER),
            "--archive",
            str(path),
            "--sha256",
            sha256,
            "--repo-name",
            REPO_NAME,
            "--commit",
            COMMIT,
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def expect_pass(name: str, result) -> None:
    if result.returncode != 0:
        raise SystemExit(
            f"FAIL: {name}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    print(f"PASS: {name}")


def expect_fail(name: str, result, phrase: str) -> None:
    combined = result.stdout + result.stderr
    if result.returncode == 0:
        raise SystemExit(f"FAIL: {name}: unexpectedly accepted")
    if phrase not in combined:
        raise SystemExit(
            f"FAIL: {name}: missing {phrase!r}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    print(f"PASS: {name} rejected")


with tempfile.TemporaryDirectory(prefix="github-archive-security-") as td:
    td = Path(td)

    valid = td / "valid.tar.gz"
    create_archive(valid)

    expect_pass(
        "valid pinned GitHub archive",
        run_verifier(valid, digest(valid)),
    )

    expect_fail(
        "wrong GitHub archive SHA-256",
        run_verifier(valid, "0" * 64),
        "SHA-256 mismatch",
    )

    expect_fail(
        "missing/invalid GitHub archive SHA-256",
        run_verifier(valid, "-"),
        "expected SHA-256 must be exactly 64",
    )

    wrong_root = td / "wrong-root.tar.gz"
    create_archive(wrong_root, root="other-project-" + COMMIT)
    expect_fail(
        "wrong GitHub archive root",
        run_verifier(wrong_root, digest(wrong_root)),
        "archive root mismatch",
    )

    unsafe = td / "unsafe.tar.gz"
    create_archive(unsafe, unsafe=True)
    expect_fail(
        "unsafe GitHub archive path",
        run_verifier(unsafe, digest(unsafe)),
        "unsafe archive member path",
    )


installer = INSTALLER.read_text(encoding="utf-8")
verify_pos = installer.find('python3 "$GITHUB_ARCHIVE_VERIFIER"')
extract_pos = installer.find('tar -xzf "$archive"')

if verify_pos < 0 or extract_pos < 0 or verify_pos >= extract_pos:
    raise SystemExit(
        "FAIL: GitHub archive verifier must run before tar extraction"
    )
print("PASS: GitHub archive verification precedes extraction")

if '"${lock_hashes[$uuid]:-}"' not in installer:
    raise SystemExit("FAIL: installer does not pass the locked GitHub digest")
print("PASS: installer passes locked GitHub archive digest")

validator = REPOSITORY_VALIDATOR.read_text(encoding="utf-8")
if "invalid GitHub archive SHA-256 pin" not in validator:
    raise SystemExit("FAIL: repository validator does not require GitHub SHA-256")
print("PASS: repository consistency requires GitHub archive SHA-256")

print("=== GITHUB ARCHIVE SECURITY TESTS: PASS ===")
