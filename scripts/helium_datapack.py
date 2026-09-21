#!/usr/bin/env python3
"""Read, safely patch, and verify Chromium DataPack v5 locale archives."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import tempfile
from pathlib import Path
from typing import Dict, Iterable, Tuple

HEADER = struct.Struct("<IIHH")
ENTRY = struct.Struct("<HI")
ALIAS = struct.Struct("<HH")
DATA_PACK_V5 = 5
UTF8_ENCODING = 1


class DataPackError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_pack(path: Path) -> tuple[int, Dict[int, bytes]]:
    data = path.read_bytes()
    if len(data) < HEADER.size:
        raise DataPackError(f"{path}: incomplete DataPack header")

    version, encoding, resource_count, alias_count = HEADER.unpack_from(data, 0)
    if version != DATA_PACK_V5:
        raise DataPackError(
            f"{path}: unsupported DataPack version {version}; expected {DATA_PACK_V5}"
        )
    if encoding != UTF8_ENCODING:
        raise DataPackError(
            f"{path}: unsupported text encoding {encoding}; expected UTF-8 ({UTF8_ENCODING})"
        )

    entries_offset = HEADER.size
    entries_size = (resource_count + 1) * ENTRY.size
    aliases_offset = entries_offset + entries_size
    aliases_size = alias_count * ALIAS.size
    if aliases_offset + aliases_size > len(data):
        raise DataPackError(f"{path}: truncated resource/alias tables")

    entries: list[tuple[int, int]] = []
    for index in range(resource_count + 1):
        rid, file_offset = ENTRY.unpack_from(data, entries_offset + index * ENTRY.size)
        if file_offset > len(data):
            raise DataPackError(f"{path}: resource entry {index} points past EOF")
        entries.append((rid, file_offset))

    for index in range(resource_count):
        if entries[index][1] > entries[index + 1][1]:
            raise DataPackError(f"{path}: resource offsets are not ordered")

    resources: Dict[int, bytes] = {}
    entry_ids: list[int] = []
    for index in range(resource_count):
        rid, start = entries[index]
        end = entries[index + 1][1]
        if rid in resources:
            raise DataPackError(f"{path}: duplicate resource id {rid}")
        resources[rid] = data[start:end]
        entry_ids.append(rid)

    for index in range(alias_count):
        rid, entry_index = ALIAS.unpack_from(data, aliases_offset + index * ALIAS.size)
        if entry_index >= resource_count:
            raise DataPackError(f"{path}: alias {rid} references invalid entry {entry_index}")
        if rid in resources:
            raise DataPackError(f"{path}: alias id {rid} duplicates an existing resource")
        resources[rid] = resources[entry_ids[entry_index]]

    return encoding, resources


def write_pack(path: Path, encoding: int, resources: Dict[int, bytes]) -> None:
    if encoding != UTF8_ENCODING:
        raise DataPackError(f"unsupported output encoding {encoding}")
    if not resources:
        raise DataPackError("refusing to write an empty locale DataPack")

    for rid, payload in resources.items():
        if not isinstance(rid, int) or not 0 <= rid <= 0xFFFF:
            raise DataPackError(f"invalid resource id {rid!r}")
        if not isinstance(payload, bytes):
            raise DataPackError(f"resource {rid} is not bytes")

    unique_entries: list[tuple[int, bytes]] = []
    aliases: list[tuple[int, int]] = []
    payload_to_index: dict[bytes, int] = {}

    for rid in sorted(resources):
        payload = resources[rid]
        entry_index = payload_to_index.get(payload)
        if entry_index is None:
            entry_index = len(unique_entries)
            payload_to_index[payload] = entry_index
            unique_entries.append((rid, payload))
        else:
            aliases.append((rid, entry_index))

    if len(unique_entries) > 0xFFFF or len(aliases) > 0xFFFF:
        raise DataPackError("DataPack v5 table count exceeds uint16 capacity")

    data_offset = (
        HEADER.size
        + (len(unique_entries) + 1) * ENTRY.size
        + len(aliases) * ALIAS.size
    )

    output = bytearray()
    output += HEADER.pack(
        DATA_PACK_V5, encoding, len(unique_entries), len(aliases)
    )

    running_offset = data_offset
    for rid, payload in unique_entries:
        output += ENTRY.pack(rid, running_offset)
        running_offset += len(payload)

    output += ENTRY.pack(0, running_offset)

    for rid, entry_index in aliases:
        output += ALIAS.pack(rid, entry_index)

    for _, payload in unique_entries:
        output += payload

    path.write_bytes(output)


def parse_info(path: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    for lineno, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split(",", 2)
        if len(parts) != 3:
            raise DataPackError(f"{path}:{lineno}: malformed .pak.info line")
        name, rid_text, _source_path = parts
        try:
            rid = int(rid_text)
        except ValueError as exc:
            raise DataPackError(
                f"{path}:{lineno}: invalid resource id {rid_text!r}"
            ) from exc
        previous = result.get(name)
        if previous is not None and previous != rid:
            raise DataPackError(
                f"{path}:{lineno}: duplicate resource name {name!r} with different ids"
            )
        result[name] = rid
    return result


def load_overlay(path: Path) -> dict:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1:
        raise DataPackError(f"{path}: unsupported overlay schema version")
    translations = document.get("translations")
    if not isinstance(translations, list) or not translations:
        raise DataPackError(f"{path}: missing translations array")

    names: set[str] = set()
    resource_ids: set[int] = set()
    for index, item in enumerate(translations):
        if not isinstance(item, dict):
            raise DataPackError(f"{path}: translation #{index} is not an object")
        for key in ("name", "resource_id", "source", "message"):
            if key not in item:
                raise DataPackError(f"{path}: translation #{index} missing {key}")
        name = item["name"]
        rid = item["resource_id"]
        source = item["source"]
        message = item["message"]
        if not isinstance(name, str) or not name:
            raise DataPackError(f"{path}: translation #{index} has invalid name")
        if not isinstance(rid, int) or not 0 <= rid <= 0xFFFF:
            raise DataPackError(f"{path}: translation {name} has invalid resource_id")
        if not isinstance(source, str) or not source:
            raise DataPackError(f"{path}: translation {name} has invalid source")
        if not isinstance(message, str) or not message:
            raise DataPackError(f"{path}: translation {name} has invalid message")
        if name in names:
            raise DataPackError(f"{path}: duplicate translation name {name}")
        if rid in resource_ids:
            raise DataPackError(f"{path}: duplicate translation resource_id {rid}")
        names.add(name)
        resource_ids.add(rid)

    return document


def decode_resource(name: str, payload: bytes) -> str:
    try:
        return payload.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise DataPackError(f"{name}: resource is not valid UTF-8") from exc


def classify_entries(
    resources: Dict[int, bytes],
    info: dict[str, int],
    overlay: dict,
    *,
    enforce_resource_ids: bool,
) -> tuple[list[tuple[dict, int, str]], list[tuple[dict, int, str]], list[tuple[dict, int, str]]]:
    source_entries = []
    translated_entries = []
    drift_entries = []

    for item in overlay["translations"]:
        name = item["name"]
        if name not in info:
            raise DataPackError(f"{name}: missing from .pak.info")
        rid = info[name]
        if enforce_resource_ids and rid != item["resource_id"]:
            raise DataPackError(
                f"{name}: resource id drift; expected {item['resource_id']}, found {rid}"
            )
        if rid not in resources:
            raise DataPackError(f"{name}: resource id {rid} missing from DataPack")
        current = decode_resource(name, resources[rid])
        row = (item, rid, current)
        if current == item["source"]:
            source_entries.append(row)
        elif current == item["message"]:
            translated_entries.append(row)
        else:
            drift_entries.append(row)

    return source_entries, translated_entries, drift_entries


def print_drift(rows: Iterable[tuple[dict, int, str]]) -> None:
    for item, rid, current in rows:
        print(
            f"WARN: {item['name']} ({rid}) differs from both audited English source "
            f"and repository translation; leaving producer value untouched",
            file=sys.stderr,
        )
        print(f"      current={current!r}", file=sys.stderr)


def cmd_validate_overlay(args: argparse.Namespace) -> int:
    overlay = load_overlay(args.overlay)
    print(
        f"PASS: valid Helium localization overlay "
        f"({len(overlay['translations'])} translations)"
    )
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    overlay = load_overlay(args.overlay)
    encoding, resources = read_pack(args.pak)
    info = parse_info(args.info)

    source_entries, translated_entries, drift_entries = classify_entries(
        resources,
        info,
        overlay,
        enforce_resource_ids=args.enforce_resource_ids,
    )

    if drift_entries:
        print_drift(drift_entries)
        if args.strict:
            raise DataPackError(
                f"{len(drift_entries)} translation(s) drifted; strict mode refuses output"
            )

    patched = dict(resources)
    for item, rid, _current in source_entries:
        patched[rid] = item["message"].encode("utf-8")

    write_pack(args.output, encoding, patched)

    out_encoding, out_resources = read_pack(args.output)
    if out_encoding != encoding:
        raise DataPackError("output encoding changed unexpectedly")
    if set(out_resources) != set(resources):
        raise DataPackError("output resource-id set differs from input")

    changed_ids = {rid for _item, rid, _current in source_entries}
    drift_ids = {rid for _item, rid, _current in drift_entries}
    for rid in resources:
        if rid in changed_ids:
            continue
        if rid in drift_ids:
            if out_resources[rid] != resources[rid]:
                raise DataPackError(f"drifted resource {rid} changed unexpectedly")
            continue
        if out_resources[rid] != resources[rid]:
            raise DataPackError(f"unmanaged resource {rid} changed unexpectedly")

    source_after, translated_after, drift_after = classify_entries(
        out_resources,
        info,
        overlay,
        enforce_resource_ids=args.enforce_resource_ids,
    )
    if source_after:
        raise DataPackError(
            f"{len(source_after)} audited English source string(s) remained after patch"
        )
    if len(drift_after) != len(drift_entries):
        raise DataPackError("output drift set changed unexpectedly")

    print(
        "PASS: Helium DataPack completion built "
        f"(patched={len(source_entries)} already={len(translated_entries)} "
        f"drift={len(drift_entries)} sha256={sha256(args.output)})"
    )
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    overlay = load_overlay(args.overlay)
    _encoding, resources = read_pack(args.pak)
    info = parse_info(args.info)

    source_entries, translated_entries, drift_entries = classify_entries(
        resources,
        info,
        overlay,
        enforce_resource_ids=args.enforce_resource_ids,
    )
    if source_entries:
        for item, rid, _current in source_entries:
            print(
                f"FAIL: {item['name']} ({rid}) still resolves to audited English source",
                file=sys.stderr,
            )
    if drift_entries:
        print_drift(drift_entries)

    if source_entries or drift_entries:
        return 1

    print(
        f"PASS: Helium Polish DataPack contains all "
        f"{len(translated_entries)} repository translations"
    )
    return 0


def self_test() -> None:
    sample = {
        1: b"alpha",
        2: b"beta",
        3: b"alpha",
        4: "zażółć".encode("utf-8"),
        65535: b"omega",
    }
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "test.pak"
        write_pack(path, UTF8_ENCODING, sample)
        encoding, decoded = read_pack(path)
        if encoding != UTF8_ENCODING or decoded != sample:
            raise DataPackError("synthetic DataPack round-trip failed")

        data = path.read_bytes()
        version, encoding32, resource_count, alias_count = HEADER.unpack_from(data, 0)
        if version != 5 or encoding32 != 1 or resource_count != 4 or alias_count != 1:
            raise DataPackError("synthetic DataPack alias layout is unexpected")


def cmd_self_test(_args: argparse.Namespace) -> int:
    self_test()
    print("PASS: Helium Chromium DataPack v5 parser/writer self-test")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Safe Chromium DataPack v5 helper for Helium Polish localization"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate-overlay")
    validate.add_argument("--overlay", type=Path, required=True)
    validate.set_defaults(func=cmd_validate_overlay)

    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("--pak", type=Path, required=True)
    apply_parser.add_argument("--info", type=Path, required=True)
    apply_parser.add_argument("--overlay", type=Path, required=True)
    apply_parser.add_argument("--output", type=Path, required=True)
    apply_parser.add_argument("--strict", action="store_true")
    apply_parser.add_argument("--enforce-resource-ids", action="store_true")
    apply_parser.set_defaults(func=cmd_apply)

    verify = subparsers.add_parser("verify")
    verify.add_argument("--pak", type=Path, required=True)
    verify.add_argument("--info", type=Path, required=True)
    verify.add_argument("--overlay", type=Path, required=True)
    verify.add_argument("--enforce-resource-ids", action="store_true")
    verify.set_defaults(func=cmd_verify)

    self_test_parser = subparsers.add_parser("self-test")
    self_test_parser.set_defaults(func=cmd_self_test)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except (DataPackError, OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
