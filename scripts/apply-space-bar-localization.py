#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Apply the repository-managed Polish localization to pristine Space Bar v39 files."
    )
    parser.add_argument("--mapping", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--dest-root", required=True, type=Path)
    args = parser.parse_args()

    mapping = json.loads(args.mapping.read_text(encoding="utf-8"))
    if mapping.get("uuid") != "space-bar@luchrioh" or mapping.get("version") != 39:
        raise SystemExit("ERROR: unsupported Space Bar localization mapping")

    files = mapping.get("files")
    if not isinstance(files, dict) or not files:
        raise SystemExit("ERROR: Space Bar localization mapping has no files")

    pattern_count = 0
    occurrence_count = 0

    for relative, spec in files.items():
        source_path = args.source_root / relative
        dest_path = args.dest_root / relative
        if not source_path.is_file():
            raise SystemExit(f"ERROR: missing pristine Space Bar file: {source_path}")

        expected_hash = spec.get("sha256")
        actual_hash = sha256(source_path)
        if actual_hash != expected_hash:
            raise SystemExit(
                f"ERROR: pristine Space Bar fingerprint mismatch: {relative}\n"
                f"expected: {expected_hash}\nactual:   {actual_hash}"
            )

        text = source_path.read_text(encoding="utf-8")
        replacements = spec.get("replacements")
        if not isinstance(replacements, list) or not replacements:
            raise SystemExit(f"ERROR: no replacements declared for {relative}")

        for replacement in replacements:
            source = replacement.get("source")
            target = replacement.get("target")
            if not isinstance(source, str) or not source:
                raise SystemExit(f"ERROR: invalid source replacement in {relative}")
            if not isinstance(target, str) or not target:
                raise SystemExit(f"ERROR: invalid target replacement in {relative}")

            occurrences = text.count(source)
            if occurrences == 0:
                raise SystemExit(
                    f"ERROR: expected Space Bar v39 text not found in {relative}: {source!r}"
                )

            text = text.replace(source, target)
            if source in text:
                raise SystemExit(
                    f"ERROR: source text remained after replacement in {relative}: {source!r}"
                )

            pattern_count += 1
            occurrence_count += occurrences

        dest_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, dest_path)
        dest_path.write_text(text, encoding="utf-8")

    print(f"Translated patterns: {pattern_count}")
    print(f"Replacement occurrences: {occurrence_count}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
