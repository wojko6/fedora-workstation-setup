#!/usr/bin/env python3
"""Audit Polish coverage for exact Ptyxis 50.1 preference/profile UI resources."""

from __future__ import annotations

import argparse
import gettext
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable

RESOURCES = (
    "/org/gnome/Ptyxis/ptyxis-preferences-window.ui",
    "/org/gnome/Ptyxis/ptyxis-profile-editor.ui",
    "/org/gnome/Ptyxis/ptyxis-profile-dialog.ui",
    "/org/gnome/Ptyxis/ptyxis-profile-row.ui",
    "/org/gnome/Ptyxis/ptyxis-shortcut-accel-dialog.ui",
    "/org/gnome/Ptyxis/ptyxis-shortcut-row.ui",
    "/org/gnome/Ptyxis/ptyxis-custom-link-editor.ui",
    "/org/gnome/Ptyxis/ptyxis-palette-preview.ui",
)

# These technical labels are intentionally identical in Polish.
ALLOWED_IDENTICAL = frozenset({"Terminal", "Control-H", "ASCII DEL"})


def iter_translatable(xml_data: bytes) -> Iterable[tuple[str, str]]:
    root = ET.fromstring(xml_data)
    seen: set[tuple[str, str]] = set()
    for elem in root.iter():
        if elem.attrib.get("translatable") != "yes":
            continue
        source = (elem.text or "").strip()
        if not source:
            continue
        context = elem.attrib.get("context") or ""
        key = (context, source)
        if key in seen:
            continue
        seen.add(key)
        yield key


def audit_pairs(
    pairs: Iterable[tuple[str, str]],
    catalog: dict[object, object],
) -> list[tuple[str, str, str]]:
    failures: list[tuple[str, str, str]] = []
    for context, source in pairs:
        key = f"{context}\x04{source}" if context else source
        if key not in catalog:
            failures.append((context, source, "missing catalog entry"))
            continue
        value = catalog[key]
        if isinstance(value, tuple):
            value = value[0] if value else ""
        if not isinstance(value, str) or not value:
            failures.append((context, source, "empty catalog translation"))
            continue
        if value == source and source not in ALLOWED_IDENTICAL:
            failures.append((context, source, "translation still equals English source"))
    return failures


def extract_resource(binary: Path, resource: str) -> bytes:
    proc = subprocess.run(
        ["gresource", "extract", str(binary), resource],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return proc.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--mo", required=True, type=Path)
    args = parser.parse_args()

    if not args.binary.is_file():
        parser.error(f"Ptyxis binary not found: {args.binary}")
    if not args.mo.is_file():
        parser.error(f"Ptyxis catalog not found: {args.mo}")

    with args.mo.open("rb") as handle:
        translations = gettext.GNUTranslations(handle)
    catalog = getattr(translations, "_catalog", {})

    all_unique: set[tuple[str, str]] = set()
    occurrence_count = 0
    failures: list[tuple[str, str, str, str]] = []

    for resource in RESOURCES:
        try:
            xml_data = extract_resource(args.binary, resource)
        except subprocess.CalledProcessError as exc:
            detail = exc.stderr.decode("utf-8", errors="replace").strip()
            print(f"FAIL: unable to extract Ptyxis resource {resource}: {detail}")
            return 1

        pairs = list(iter_translatable(xml_data))
        occurrence_count += len(pairs)
        all_unique.update(pairs)

        for context, source, reason in audit_pairs(pairs, catalog):
            failures.append((resource, context, source, reason))

    if failures:
        for resource, context, source, reason in failures:
            ctx = f" context={context!r}" if context else ""
            print(f"FAIL: {resource}:{ctx} {source!r}: {reason}")
        print(
            "FAIL: Ptyxis resource localization incomplete: "
            f"{len(failures)} unresolved occurrence(s)"
        )
        return 1

    identity_present = sum(
        1
        for context, source in all_unique
        if source in ALLOWED_IDENTICAL
        and (f"{context}\x04{source}" if context else source) in catalog
    )

    print(f"PASS: Ptyxis audited UI resources: {len(RESOURCES)}")
    print(f"PASS: translatable resource occurrences: {occurrence_count}")
    print(f"PASS: unique translatable resource strings: {len(all_unique)}")
    print(f"PASS: reviewed identity translations: {identity_present}")
    print("PASS: unresolved audited resource strings: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
