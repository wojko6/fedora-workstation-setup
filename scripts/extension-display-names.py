#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "gnome" / "extension-display-names-pl.tsv"
EXT_ROOT = Path.home() / ".local/share/gnome-shell/extensions"


class ManagedMetadataError(RuntimeError):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_entries() -> list[dict[str, str]]:
    with MANIFEST.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        expected = [
            "uuid",
            "runtime_version",
            "version_name",
            "metadata_sha256",
            "original_name",
            "pl_name",
        ]
        if reader.fieldnames != expected:
            raise ManagedMetadataError(
                f"unexpected manifest header: {reader.fieldnames!r}"
            )
        rows = [dict(row) for row in reader]

    seen: set[str] = set()
    for row in rows:
        uuid = row["uuid"].strip()
        if not uuid or uuid in seen:
            raise ManagedMetadataError(f"invalid or duplicate UUID: {uuid!r}")
        if not re.fullmatch(r"[0-9a-f]{64}", row["metadata_sha256"].strip()):
            raise ManagedMetadataError(f"invalid metadata SHA-256: {uuid}")
        if not row["runtime_version"].strip().isdigit():
            raise ManagedMetadataError(f"invalid runtime version: {uuid}")
        if not row["original_name"].strip() or not row["pl_name"].strip():
            raise ManagedMetadataError(f"empty display name: {uuid}")
        seen.add(uuid)
    return rows


def entry_for(uuid: str) -> dict[str, str]:
    for row in load_entries():
        if row["uuid"] == uuid:
            return row
    raise ManagedMetadataError(f"UUID not managed: {uuid}")


def replace_name(raw: bytes, old: str, new: str) -> bytes:
    old_json = json.dumps(old, ensure_ascii=False).encode()
    new_json = json.dumps(new, ensure_ascii=False).encode()
    pattern = re.compile(rb'("name"\s*:\s*)' + re.escape(old_json))
    matches = list(pattern.finditer(raw))
    if len(matches) != 1:
        raise ManagedMetadataError(
            f"expected exactly one metadata name {old!r}, found {len(matches)}"
        )
    return pattern.sub(lambda m: m.group(1) + new_json, raw, count=1)


def metadata_path(uuid: str) -> Path:
    return EXT_ROOT / uuid / "metadata.json"


def validate_version(row: dict[str, str], data: dict[str, object]) -> None:
    actual_version = data.get("version")
    if isinstance(actual_version, bool) or str(actual_version) != row["runtime_version"]:
        raise ManagedMetadataError(
            f"runtime version drift for {row['uuid']}: "
            f"expected {row['runtime_version']}, found {actual_version!r}"
        )

    actual_version_name = data.get("version-name")
    normalized = "-" if actual_version_name is None else str(actual_version_name)
    if normalized != row["version_name"]:
        raise ManagedMetadataError(
            f"version-name drift for {row['uuid']}: "
            f"expected {row['version_name']!r}, found {normalized!r}"
        )


def classify(row: dict[str, str]) -> tuple[str, Path, bytes, bytes]:
    path = metadata_path(row["uuid"])
    if not path.is_file():
        raise ManagedMetadataError(f"metadata missing: {row['uuid']}")

    raw = path.read_bytes()
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ManagedMetadataError(
            f"invalid metadata JSON for {row['uuid']}: {exc}"
        ) from exc

    validate_version(row, data)
    pristine_sha = row["metadata_sha256"]

    if digest(raw) == pristine_sha:
        if data.get("name") != row["original_name"]:
            raise ManagedMetadataError(
                f"pristine hash/name mismatch for {row['uuid']}"
            )
        localized = replace_name(raw, row["original_name"], row["pl_name"])
        return "pristine", path, raw, localized

    if data.get("name") == row["pl_name"]:
        restored = replace_name(raw, row["pl_name"], row["original_name"])
        if digest(restored) == pristine_sha:
            return "localized", path, raw, raw

    raise ManagedMetadataError(
        f"metadata is neither pristine nor exact managed localization for "
        f"{row['uuid']}: sha256={digest(raw)}, name={data.get('name')!r}"
    )


def install_one(row: dict[str, str]) -> None:
    state, path, _raw, localized = classify(row)
    if state == "pristine":
        path.write_bytes(localized)
        print(f"PASS: localized {row['uuid']} -> {row['pl_name']}")
    else:
        print(f"PASS: already localized {row['uuid']} -> {row['pl_name']}")


def verify_one(row: dict[str, str], allow_pristine: bool) -> None:
    state, _path, _raw, _localized = classify(row)
    if state == "pristine" and not allow_pristine:
        raise ManagedMetadataError(
            f"display name still pristine for {row['uuid']}: "
            f"{row['original_name']}"
        )
    print(f"PASS: managed metadata state {row['uuid']} = {state}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Version-pinned Polish display-name manager for GNOME extensions."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("install")
    sub.add_parser("verify")

    check = sub.add_parser("check-one")
    check.add_argument("--uuid", required=True)
    check.add_argument("--allow-pristine", action="store_true")

    args = parser.parse_args()

    try:
        if args.command == "install":
            for row in load_entries():
                install_one(row)
        elif args.command == "verify":
            for row in load_entries():
                verify_one(row, allow_pristine=False)
        else:
            verify_one(entry_for(args.uuid), allow_pristine=args.allow_pristine)
    except (OSError, ManagedMetadataError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
