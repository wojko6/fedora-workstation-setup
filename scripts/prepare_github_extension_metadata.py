#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


class MetadataError(Exception):
    pass


def reject_duplicate_keys(pairs):
    result = {}

    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key!r}")
        result[key] = value

    return result


def load_metadata(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise MetadataError(
            f"metadata.json is not valid UTF-8: {exc}"
        ) from exc

    try:
        data = json.loads(
            text,
            object_pairs_hook=reject_duplicate_keys,
        )
    except (json.JSONDecodeError, ValueError) as exc:
        raise MetadataError(
            f"metadata.json is invalid JSON: {exc}"
        ) from exc

    if not isinstance(data, dict):
        raise MetadataError(
            "metadata.json root must be a JSON object"
        )

    return data


def prepare(
    path: Path,
    expected_uuid: str,
    runtime_version: int,
    shell_major: str,
) -> None:
    data = load_metadata(path)

    metadata_uuid = data.get("uuid")

    if metadata_uuid != expected_uuid:
        raise MetadataError(
            "UUID mismatch: "
            f"expected {expected_uuid!r}, found {metadata_uuid!r}"
        )

    shell_versions = data.get("shell-version")

    if not isinstance(shell_versions, list) or not shell_versions:
        raise MetadataError(
            "shell-version must be a non-empty JSON array"
        )

    normalized_shell_versions = []

    for value in shell_versions:
        if not isinstance(value, (str, int)):
            raise MetadataError(
                "shell-version entries must be strings or integers"
            )

        normalized_shell_versions.append(str(value))

    if shell_major not in normalized_shell_versions:
        raise MetadataError(
            f"GNOME Shell {shell_major} compatibility is not declared"
        )

    existing_version = data.get("version")

    if existing_version is not None:
        if isinstance(existing_version, bool) or not isinstance(
            existing_version,
            int,
        ):
            raise MetadataError(
                "existing metadata version must be an integer"
            )

        if existing_version != runtime_version:
            raise MetadataError(
                "runtime version mismatch: "
                f"expected {runtime_version}, "
                f"found {existing_version}"
            )

    elif "version-name" not in data:
        raise MetadataError(
            'metadata.json has neither "version" nor "version-name"'
        )

    data["version"] = runtime_version

    if (
        expected_uuid == "dhruva@narkagni"
        and "gettext-domain" not in data
    ):
        data["gettext-domain"] = "dhruva"

    path.write_text(
        json.dumps(
            data,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    # Re-open what we actually wrote.
    written = load_metadata(path)

    if written.get("uuid") != expected_uuid:
        raise MetadataError(
            "written metadata UUID verification failed"
        )

    if written.get("version") != runtime_version:
        raise MetadataError(
            "written runtime version verification failed"
        )

    if shell_major not in [
        str(x)
        for x in written.get("shell-version", [])
    ]:
        raise MetadataError(
            "written shell compatibility verification failed"
        )


def main() -> int:
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--metadata",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--uuid",
        required=True,
    )
    parser.add_argument(
        "--version",
        required=True,
        type=int,
    )
    parser.add_argument(
        "--shell-major",
        required=True,
    )

    args = parser.parse_args()

    try:
        prepare(
            path=args.metadata,
            expected_uuid=args.uuid,
            runtime_version=args.version,
            shell_major=args.shell_major,
        )
    except (MetadataError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(
        "PASS: strict GitHub metadata validation/preparation: "
        f"{args.uuid} v{args.version}, GNOME {args.shell_major}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
