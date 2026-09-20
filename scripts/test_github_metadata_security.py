#!/usr/bin/env python3

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

PREPARER = (
    ROOT
    / "scripts"
    / "prepare_github_extension_metadata.py"
)

UUID = "dhruva@narkagni"
VERSION = 17
SHELL = "50"


def run(metadata: Path):
    return subprocess.run(
        [
            sys.executable,
            str(PREPARER),
            "--metadata",
            str(metadata),
            "--uuid",
            UUID,
            "--version",
            str(VERSION),
            "--shell-major",
            SHELL,
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def write_json(path: Path, data):
    path.write_text(
        json.dumps(data, indent=2) + "\n",
        encoding="utf-8",
    )


def expect_pass(name, result):
    if result.returncode != 0:
        raise SystemExit(
            f"FAIL: {name}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    print(f"PASS: {name}")


def expect_fail(name, result, phrase):
    combined = result.stdout + result.stderr

    if result.returncode == 0:
        raise SystemExit(
            f"FAIL: {name}: unexpectedly accepted"
        )

    if phrase not in combined:
        raise SystemExit(
            f"FAIL: {name}: missing {phrase!r}\n"
            f"{combined}"
        )

    print(f"PASS: {name} rejected")


with tempfile.TemporaryDirectory(
    prefix="github-metadata-security-"
) as td:
    td = Path(td)

    valid = td / "valid.json"

    write_json(
        valid,
        {
            "uuid": UUID,
            "name": "Dhruva",
            "shell-version": [
                "45",
                "46",
                "47",
                "48",
                "49",
                "50",
                "51",
            ],
            "version-name": "2.0",
        },
    )

    expect_pass(
        "valid Dhruva metadata",
        run(valid),
    )

    prepared = json.loads(
        valid.read_text(encoding="utf-8")
    )

    if prepared["version"] != VERSION:
        raise SystemExit(
            "FAIL: runtime version was not written"
        )

    if prepared["gettext-domain"] != "dhruva":
        raise SystemExit(
            "FAIL: gettext-domain was not written"
        )

    print(
        "PASS: deterministic runtime metadata written"
    )

    wrong_uuid = td / "wrong-uuid.json"

    write_json(
        wrong_uuid,
        {
            "uuid": "wrong@example",
            "shell-version": ["50"],
            "version-name": "2.0",
        },
    )

    expect_fail(
        "wrong UUID",
        run(wrong_uuid),
        "UUID mismatch",
    )

    wrong_shell = td / "wrong-shell.json"

    write_json(
        wrong_shell,
        {
            "uuid": UUID,
            "shell-version": ["48", "49"],
            "version-name": "2.0",
        },
    )

    expect_fail(
        "missing GNOME 50 compatibility",
        run(wrong_shell),
        "GNOME Shell 50 compatibility is not declared",
    )

    malformed = td / "malformed.json"

    malformed.write_text(
        '{"uuid": "dhruva@narkagni", BAD}',
        encoding="utf-8",
    )

    expect_fail(
        "malformed JSON",
        run(malformed),
        "invalid JSON",
    )

    duplicate = td / "duplicate.json"

    duplicate.write_text(
        '''{
  "uuid": "dhruva@narkagni",
  "uuid": "wrong@example",
  "shell-version": ["50"],
  "version-name": "2.0"
}
''',
        encoding="utf-8",
    )

    expect_fail(
        "duplicate JSON key",
        run(duplicate),
        "duplicate JSON key",
    )

    wrong_version = td / "wrong-version.json"

    write_json(
        wrong_version,
        {
            "uuid": UUID,
            "shell-version": ["50"],
            "version": 16,
            "version-name": "2.0",
        },
    )

    expect_fail(
        "wrong existing runtime version",
        run(wrong_version),
        "runtime version mismatch",
    )

    bad_version = td / "bad-version.json"

    write_json(
        bad_version,
        {
            "uuid": UUID,
            "shell-version": ["50"],
            "version": "17",
            "version-name": "2.0",
        },
    )

    expect_fail(
        "invalid existing version type",
        run(bad_version),
        "existing metadata version must be an integer",
    )

print("=== GITHUB METADATA SECURITY TESTS: PASS ===")
