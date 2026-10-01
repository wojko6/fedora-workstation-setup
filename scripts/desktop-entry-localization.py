#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rpm_owner(path: Path) -> str:
    proc = subprocess.run(
        ["rpm", "-qf", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def is_vm() -> bool:
    proc = subprocess.run(
        ["systemd-detect-virt"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    value = proc.stdout.strip()
    return proc.returncode == 0 and value not in ("", "none")


def patch_desktop(text: str, translations: dict[str, str]) -> str:
    lines = text.splitlines(keepends=True)

    start = None
    end = len(lines)

    for i, line in enumerate(lines):
        if line.rstrip("\r\n") == "[Desktop Entry]":
            if start is not None:
                fail("multiple [Desktop Entry] sections")
            start = i

    if start is None:
        fail("missing [Desktop Entry] section")

    for i in range(start + 1, len(lines)):
        if lines[i].startswith("["):
            end = i
            break

    for key, wanted in translations.items():
        default_prefix = f"{key}="
        localized_prefix = f"{key}[pl]="

        default_positions = [
            i for i in range(start + 1, end)
            if lines[i].startswith(default_prefix)
        ]

        if len(default_positions) != 1:
            fail(
                f"expected exactly one {default_prefix!r} "
                f"in main section, found {len(default_positions)}"
            )

        localized_positions = [
            i for i in range(start + 1, end)
            if lines[i].startswith(localized_prefix)
        ]

        if len(localized_positions) > 1:
            fail(f"duplicate {localized_prefix!r}")

        wanted_line = localized_prefix + wanted

        if localized_positions:
            i = localized_positions[0]
            actual = lines[i].rstrip("\r\n")

            if actual != wanted_line:
                fail(
                    f"existing {localized_prefix} differs: "
                    f"{actual!r} != {wanted_line!r}"
                )
            continue

        i = default_positions[0]
        newline = "\r\n" if lines[i].endswith("\r\n") else "\n"
        lines.insert(i + 1, wanted_line + newline)
        end += 1

    return "".join(lines)


def validate_manifest(data: dict) -> None:
    if data.get("schema_version") != 1:
        fail("unsupported manifest schema_version")

    entries = data.get("entries")

    if not isinstance(entries, list) or not entries:
        fail("manifest entries missing")

    names = set()

    for entry in entries:
        desktop = entry.get("desktop")
        source = entry.get("source")
        digest = entry.get("sha256")
        owner = entry.get("owner")
        translations = entry.get("translations")

        if not isinstance(desktop, str) or not desktop.endswith(".desktop"):
            fail(f"invalid desktop name: {desktop!r}")

        if desktop in names:
            fail(f"duplicate desktop entry: {desktop}")
        names.add(desktop)

        if not isinstance(source, str) or not source.startswith("/"):
            fail(f"invalid source for {desktop}")

        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(c not in "0123456789abcdef" for c in digest)
        ):
            fail(f"invalid SHA-256 for {desktop}")

        if not isinstance(owner, str) or not owner:
            fail(f"missing RPM owner for {desktop}")

        if not isinstance(translations, dict) or not translations:
            fail(f"missing translations for {desktop}")

        allowed = {"Name", "GenericName", "Comment"}

        for key, value in translations.items():
            if key not in allowed:
                fail(f"unsupported key {key!r} for {desktop}")
            if not isinstance(value, str) or not value:
                fail(f"empty translation {key} for {desktop}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument(
        "--mode",
        choices=("install", "verify", "manifest"),
        required=True,
    )
    args = parser.parse_args()

    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    validate_manifest(data)

    if args.mode == "manifest":
        print(
            f"PASS: desktop localization manifest "
            f"({len(data['entries'])} launchers)"
        )
        return 0

    target_dir = Path.home() / ".local/share/applications"

    if args.mode == "install":
        target_dir.mkdir(parents=True, exist_ok=True)

    vm = is_vm()
    processed = 0
    skipped = 0

    for entry in data["entries"]:
        desktop = entry["desktop"]
        source = Path(entry["source"])
        target = target_dir / desktop

        if (
            vm
            and entry.get("optional_in_vm") is True
            and not source.is_file()
        ):
            print(f"SKIP: {desktop} is host-only in VM")
            skipped += 1
            continue

        if not source.is_file():
            fail(f"source missing for {desktop}: {source}")

        actual_sha = sha256(source)

        if actual_sha != entry["sha256"]:
            fail(
                f"{desktop} source fingerprint drift: "
                f"expected {entry['sha256']}, found {actual_sha}"
            )

        owner = rpm_owner(source)

        if owner != entry["owner"]:
            fail(
                f"{desktop} RPM owner drift: "
                f"expected {entry['owner']!r}, found {owner!r}"
            )

        source_text = source.read_text(encoding="utf-8")
        expected = patch_desktop(
            source_text,
            entry["translations"],
        )

        expected_bytes = expected.encode("utf-8")

        if args.mode == "install":
            tmp = target.with_suffix(target.suffix + ".tmp")
            tmp.write_bytes(expected_bytes)
            os.chmod(tmp, 0o644)
            os.replace(tmp, target)

        if not target.is_file():
            fail(f"localized launcher missing: {target}")

        if target.read_bytes() != expected_bytes:
            fail(
                f"{desktop} differs from deterministic reconstruction"
            )

        print(
            f"PASS: {desktop} "
            f"({len(entry['translations'])} managed Polish fields)"
        )
        processed += 1

    print(
        f"PASS: RPM desktop localization: "
        f"processed={processed} skipped={skipped}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
