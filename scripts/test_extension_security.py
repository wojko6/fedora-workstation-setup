#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFIER = ROOT / "scripts" / "verify_ego_extension.py"

UUID = "example@test"
VERSION = 42
SHELL = "50"


def create_archive(
    path: Path,
    *,
    uuid: str = UUID,
    version: int = VERSION,
    shells=None,
    raw_metadata: bytes | None = None,
):
    if shells is None:
        shells = ["49", "50"]

    if raw_metadata is None:
        metadata = {
            "uuid": uuid,
            "name": "Security Test Extension",
            "version": version,
            "shell-version": shells,
        }

        raw_metadata = json.dumps(
            metadata,
            ensure_ascii=False,
        ).encode("utf-8")

    with zipfile.ZipFile(
        path,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as zf:
        zf.writestr("metadata.json", raw_metadata)
        zf.writestr("extension.js", "// fixture\n")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_verifier(
    archive: Path,
    sha256: str,
    *,
    uuid: str = UUID,
    version: int = VERSION,
    shell: str = SHELL,
):
    return subprocess.run(
        [
            sys.executable,
            str(VERIFIER),
            "--archive",
            str(archive),
            "--sha256",
            sha256,
            "--uuid",
            uuid,
            "--version",
            str(version),
            "--shell-major",
            shell,
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def expect_pass(name: str, result):
    if result.returncode != 0:
        raise SystemExit(
            f"FAIL: {name}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    print(f"PASS: {name}")


def expect_fail(name: str, result, expected: str):
    combined = result.stdout + result.stderr

    if result.returncode == 0:
        raise SystemExit(
            f"FAIL: {name}: verifier unexpectedly accepted fixture"
        )

    if expected not in combined:
        raise SystemExit(
            f"FAIL: {name}: expected message {expected!r}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    print(f"PASS: {name} rejected")


with tempfile.TemporaryDirectory(
    prefix="extension-security-tests-"
) as tmp:
    tmp = Path(tmp)

    valid = tmp / "valid.zip"
    create_archive(valid)

    expect_pass(
        "valid archive",
        run_verifier(valid, digest(valid)),
    )

    expect_fail(
        "wrong SHA-256",
        run_verifier(valid, "0" * 64),
        "SHA-256 mismatch",
    )

    wrong_uuid = tmp / "wrong-uuid.zip"
    create_archive(
        wrong_uuid,
        uuid="wrong@test",
    )

    expect_fail(
        "wrong UUID",
        run_verifier(wrong_uuid, digest(wrong_uuid)),
        "UUID mismatch",
    )

    malformed = tmp / "malformed-json.zip"
    create_archive(
        malformed,
        raw_metadata=b'{"uuid": "example@test", INVALID}',
    )

    expect_fail(
        "malformed JSON",
        run_verifier(malformed, digest(malformed)),
        "invalid JSON",
    )

    duplicate = tmp / "duplicate-json.zip"
    create_archive(
        duplicate,
        raw_metadata=(
            b'{"uuid":"example@test",'
            b'"uuid":"wrong@test",'
            b'"version":42,'
            b'"shell-version":["50"]}'
        ),
    )

    expect_fail(
        "duplicate JSON key",
        run_verifier(
            duplicate,
            digest(duplicate),
        ),
        "duplicate JSON key",
    )

    wrong_version = tmp / "wrong-version.zip"
    create_archive(
        wrong_version,
        version=41,
    )

    expect_fail(
        "wrong runtime version",
        run_verifier(
            wrong_version,
            digest(wrong_version),
        ),
        "runtime version mismatch",
    )

    wrong_shell = tmp / "wrong-shell.zip"
    create_archive(
        wrong_shell,
        shells=["48", "49"],
    )

    expect_fail(
        "missing GNOME 50 compatibility",
        run_verifier(
            wrong_shell,
            digest(wrong_shell),
        ),
        "GNOME Shell 50 compatibility is not declared",
    )

print("=== EXTENSION SECURITY TESTS: PASS ===")
