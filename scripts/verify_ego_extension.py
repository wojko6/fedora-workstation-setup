#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path


class VerificationError(Exception):
    pass


def reject_duplicate_keys(pairs):
    result = {}

    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key!r}")
        result[key] = value

    return result


def load_metadata(raw: bytes) -> dict:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise VerificationError(
            f"metadata.json is not valid UTF-8: {exc}"
        ) from exc

    try:
        data = json.loads(
            text,
            object_pairs_hook=reject_duplicate_keys,
        )
    except (json.JSONDecodeError, ValueError) as exc:
        raise VerificationError(
            f"metadata.json is invalid JSON: {exc}"
        ) from exc

    if not isinstance(data, dict):
        raise VerificationError(
            "metadata.json root must be a JSON object"
        )

    return data


def verify(
    archive: Path,
    expected_sha256: str,
    expected_uuid: str,
    expected_version: int,
    shell_major: str,
) -> None:
    if not archive.is_file():
        raise VerificationError(
            f"archive does not exist: {archive}"
        )

    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        raise VerificationError(
            "expected SHA-256 must be exactly 64 lowercase hexadecimal characters"
        )

    actual_sha256 = hashlib.sha256(
        archive.read_bytes()
    ).hexdigest()

    if actual_sha256 != expected_sha256:
        raise VerificationError(
            "SHA-256 mismatch: "
            f"expected {expected_sha256}, found {actual_sha256}"
        )

    try:
        with zipfile.ZipFile(archive) as zf:
            bad_member = zf.testzip()

            if bad_member is not None:
                raise VerificationError(
                    f"corrupt ZIP member: {bad_member}"
                )

            try:
                raw_metadata = zf.read("metadata.json")
            except KeyError as exc:
                raise VerificationError(
                    "archive does not contain metadata.json"
                ) from exc

    except zipfile.BadZipFile as exc:
        raise VerificationError(
            f"archive is not a valid ZIP file: {exc}"
        ) from exc

    metadata = load_metadata(raw_metadata)

    metadata_uuid = metadata.get("uuid")

    if metadata_uuid != expected_uuid:
        raise VerificationError(
            "UUID mismatch: "
            f"expected {expected_uuid!r}, found {metadata_uuid!r}"
        )

    metadata_version = metadata.get("version")

    if isinstance(metadata_version, bool) or not isinstance(
        metadata_version, int
    ):
        raise VerificationError(
            "metadata version must be an integer"
        )

    if metadata_version != expected_version:
        raise VerificationError(
            "runtime version mismatch: "
            f"expected {expected_version}, found {metadata_version}"
        )

    shell_versions = metadata.get("shell-version")

    if not isinstance(shell_versions, list) or not shell_versions:
        raise VerificationError(
            "shell-version must be a non-empty JSON array"
        )

    normalized_shell_versions = []

    for value in shell_versions:
        if not isinstance(value, (str, int)):
            raise VerificationError(
                "shell-version entries must be strings or integers"
            )

        normalized_shell_versions.append(str(value))

    if shell_major not in normalized_shell_versions:
        raise VerificationError(
            f"GNOME Shell {shell_major} compatibility is not declared"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Verify a pinned extensions.gnome.org archive "
            "before installation."
        )
    )

    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--uuid", required=True)
    parser.add_argument("--version", required=True, type=int)
    parser.add_argument("--shell-major", required=True)

    args = parser.parse_args()

    try:
        verify(
            archive=args.archive,
            expected_sha256=args.sha256,
            expected_uuid=args.uuid,
            expected_version=args.version,
            shell_major=args.shell_major,
        )
    except VerificationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(
        "PASS: verified "
        f"{args.uuid} v{args.version}: "
        "SHA-256, JSON metadata, UUID, runtime version "
        f"and GNOME Shell {args.shell_major} compatibility"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
