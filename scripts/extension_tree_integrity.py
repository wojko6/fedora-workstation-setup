#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

USER_PREFIX = "~/.local/share/gnome-shell/extensions/"
LOCK_HEADER = ["uuid", "runtime_version", "tree_sha256"]


class IntegrityError(RuntimeError):
    pass


def _record(digest: "hashlib._Hash", *fields: str) -> None:
    for field in fields:
        digest.update(field.encode("utf-8", "surrogateescape"))
        digest.update(b"\0")


def tree_sha256(root: Path) -> str:
    root = root.resolve()
    if not root.is_dir():
        raise IntegrityError(f"extension tree is not a directory: {root}")

    digest = hashlib.sha256()
    _record(digest, "GNOME-EXTENSION-TREE-V1")

    def walk(directory: Path) -> None:
        entries = sorted(
            os.scandir(directory),
            key=lambda entry: os.fsencode(entry.name),
        )

        for entry in entries:
            path = Path(entry.path)
            relative = path.relative_to(root).as_posix()
            st = entry.stat(follow_symlinks=False)

            if stat.S_ISLNK(st.st_mode):
                _record(digest, "L", relative, os.readlink(path))
                continue

            if stat.S_ISDIR(st.st_mode):
                _record(digest, "D", relative)
                walk(path)
                continue

            if stat.S_ISREG(st.st_mode):
                file_digest = hashlib.sha256()
                with path.open("rb") as fh:
                    for chunk in iter(lambda: fh.read(1024 * 1024), b""):
                        file_digest.update(chunk)

                _record(
                    digest,
                    "F",
                    relative,
                    f"{stat.S_IMODE(st.st_mode):04o}",
                    str(st.st_size),
                    file_digest.hexdigest(),
                )
                continue

            raise IntegrityError(
                f"unsupported file type in extension tree: {relative}"
            )

    walk(root)
    return digest.hexdigest()


def read_enabled(path: Path) -> set[str]:
    enabled: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line in enabled:
            raise IntegrityError(f"duplicate enabled extension: {line}")
        enabled.add(line)
    return enabled


def read_inventory(path: Path) -> dict[str, dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh, delimiter="\t"))

    result: dict[str, dict[str, str]] = {}
    for row in rows:
        uuid = (row.get("uuid") or "").strip()
        if not uuid:
            continue
        if uuid in result:
            raise IntegrityError(f"duplicate inventory UUID: {uuid}")
        result[uuid] = row
    return result


def expected_user_extensions(
    inventory_path: Path,
    enabled_path: Path,
) -> list[tuple[str, str]]:
    inventory = read_inventory(inventory_path)
    enabled = read_enabled(enabled_path)
    result: list[tuple[str, str]] = []

    for uuid in sorted(enabled):
        row = inventory.get(uuid)
        if row is None:
            raise IntegrityError(f"enabled extension missing from inventory: {uuid}")

        location = (row.get("location") or "").strip()
        if not location.startswith(USER_PREFIX):
            continue

        version = (row.get("version") or "").strip()
        if not version:
            raise IntegrityError(f"user extension version missing: {uuid}")

        result.append((uuid, version))

    return result


def installed_metadata_version(extension_dir: Path) -> str:
    metadata_path = extension_dir / "metadata.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise IntegrityError(
            f"cannot read extension metadata: {metadata_path}: {exc}"
        ) from exc

    version = metadata.get("version")
    if isinstance(version, bool) or not isinstance(version, (int, str)):
        raise IntegrityError(
            f"invalid metadata version in {metadata_path}: {version!r}"
        )

    return str(version)


def generate_lock(
    inventory_path: Path,
    enabled_path: Path,
    extensions_root: Path,
) -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []

    for uuid, expected_version in expected_user_extensions(
        inventory_path, enabled_path
    ):
        extension_dir = extensions_root / uuid
        if not extension_dir.is_dir():
            raise IntegrityError(f"required extension tree missing: {uuid}")

        actual_version = installed_metadata_version(extension_dir)
        if actual_version != expected_version:
            raise IntegrityError(
                f"extension version mismatch for {uuid}: "
                f"expected {expected_version}, found {actual_version}"
            )

        rows.append(
            (uuid, expected_version, tree_sha256(extension_dir))
        )

    return rows


def read_tree_lock(path: Path) -> dict[str, tuple[str, str]]:
    with path.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        if reader.fieldnames != LOCK_HEADER:
            raise IntegrityError(
                f"unexpected tree-lock header: {reader.fieldnames!r}"
            )

        result: dict[str, tuple[str, str]] = {}
        for row in reader:
            uuid = (row.get("uuid") or "").strip()
            version = (row.get("runtime_version") or "").strip()
            digest = (row.get("tree_sha256") or "").strip()

            if not uuid:
                raise IntegrityError("tree lock contains empty UUID")
            if uuid in result:
                raise IntegrityError(f"duplicate tree-lock UUID: {uuid}")
            if len(digest) != 64 or any(
                char not in "0123456789abcdef" for char in digest
            ):
                raise IntegrityError(
                    f"invalid tree SHA-256 for {uuid}: {digest!r}"
                )

            result[uuid] = (version, digest)

    return result


def verify_lock(
    lock_path: Path,
    inventory_path: Path,
    enabled_path: Path,
    extensions_root: Path,
) -> int:
    expected = expected_user_extensions(inventory_path, enabled_path)
    locked = read_tree_lock(lock_path)

    expected_uuids = {uuid for uuid, _version in expected}
    locked_uuids = set(locked)
    ok = True

    missing = sorted(expected_uuids - locked_uuids)
    extra = sorted(locked_uuids - expected_uuids)

    for uuid in missing:
        print(f"FAIL: extension tree lock missing: {uuid}")
        ok = False

    for uuid in extra:
        print(f"FAIL: unexpected extension tree lock entry: {uuid}")
        ok = False

    for uuid, expected_version in expected:
        lock = locked.get(uuid)
        if lock is None:
            continue

        locked_version, expected_digest = lock
        if locked_version != expected_version:
            print(
                "FAIL: extension tree lock version mismatch: "
                f"{uuid}: lock={locked_version} inventory={expected_version}"
            )
            ok = False
            continue

        extension_dir = extensions_root / uuid
        if not extension_dir.is_dir():
            print(f"FAIL: required extension tree missing: {uuid}")
            ok = False
            continue

        try:
            actual_version = installed_metadata_version(extension_dir)
            actual_digest = tree_sha256(extension_dir)
        except IntegrityError as exc:
            print(f"FAIL: {exc}")
            ok = False
            continue

        if actual_version != expected_version:
            print(
                "FAIL: installed extension metadata version mismatch: "
                f"{uuid}: expected={expected_version} found={actual_version}"
            )
            ok = False
            continue

        if actual_digest == expected_digest:
            print(
                f"PASS: extension tree integrity {uuid} "
                f"= {actual_digest}"
            )
        else:
            print(
                "FAIL: extension tree integrity drift: "
                f"{uuid}: expected={expected_digest} found={actual_digest}"
            )
            ok = False

    return 0 if ok else 1


def command_hash(args: argparse.Namespace) -> int:
    print(tree_sha256(Path(args.path)))
    return 0


def command_generate(args: argparse.Namespace) -> int:
    rows = generate_lock(
        Path(args.inventory),
        Path(args.enabled),
        Path(args.extensions_root).expanduser(),
    )
    print("\t".join(LOCK_HEADER))
    for row in rows:
        print("\t".join(row))
    return 0


def command_verify(args: argparse.Namespace) -> int:
    return verify_lock(
        Path(args.lock),
        Path(args.inventory),
        Path(args.enabled),
        Path(args.extensions_root).expanduser(),
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Deterministic GNOME extension tree integrity helper."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    hash_parser = sub.add_parser("hash")
    hash_parser.add_argument("--path", required=True)
    hash_parser.set_defaults(func=command_hash)

    generate = sub.add_parser("generate")
    generate.add_argument("--inventory", required=True)
    generate.add_argument("--enabled", required=True)
    generate.add_argument(
        "--extensions-root",
        default="~/.local/share/gnome-shell/extensions",
    )
    generate.set_defaults(func=command_generate)

    verify = sub.add_parser("verify")
    verify.add_argument("--lock", required=True)
    verify.add_argument("--inventory", required=True)
    verify.add_argument("--enabled", required=True)
    verify.add_argument(
        "--extensions-root",
        default="~/.local/share/gnome-shell/extensions",
    )
    verify.set_defaults(func=command_verify)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        return args.func(args)
    except IntegrityError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
