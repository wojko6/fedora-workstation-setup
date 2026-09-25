#!/usr/bin/env python3
"""Static consistency checks for repository-managed Polish localization."""

from __future__ import annotations

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALIZATION = ROOT / "localization"


def decode_po_string(token: str) -> str:
    value = ast.literal_eval(token)
    if not isinstance(value, str):
        raise ValueError(f"not a PO string: {token!r}")
    return value


def parse_po(path: Path) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    current: dict[str, object] = {}
    active: str | None = None

    def flush() -> None:
        nonlocal current, active
        if "msgid" in current:
            entries.append(current)
        current = {}
        active = None

    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("msgctxt "):
            if "msgid" in current:
                flush()
            current["msgctxt"] = decode_po_string(raw[len("msgctxt "):])
            active = "msgctxt"
        elif raw.startswith("msgid "):
            if "msgid" in current:
                flush()
            current["msgid"] = decode_po_string(raw[len("msgid "):])
            active = "msgid"
        elif raw.startswith("msgid_plural "):
            current["msgid_plural"] = decode_po_string(raw[len("msgid_plural "):])
            active = "msgid_plural"
        elif raw.startswith("msgstr "):
            current["msgstr"] = decode_po_string(raw[len("msgstr "):])
            active = "msgstr"
        elif re.match(r"msgstr\[\d+\] ", raw):
            key, token = raw.split(" ", 1)
            current[key] = decode_po_string(token)
            active = key
        elif raw.startswith('"') and active is not None:
            current[active] = str(current.get(active, "")) + decode_po_string(raw)
        elif not raw.strip():
            flush()

    flush()
    return entries


def header_value(path: Path, name: str) -> str | None:
    header = next((e for e in parse_po(path) if e.get("msgid") == ""), None)
    if header is None:
        return None
    text = str(header.get("msgstr", ""))
    match = re.search(rf"^{re.escape(name)}:\s*(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def singular_translation(path: Path, msgid: str, msgctxt: str | None = None) -> str:
    matches = [
        e
        for e in parse_po(path)
        if e.get("msgid") == msgid and e.get("msgctxt") == msgctxt
    ]
    if len(matches) != 1:
        raise AssertionError(
            f"{path.relative_to(ROOT)}: expected one entry for {msgid!r}"
            f" (context={msgctxt!r}), found {len(matches)}"
        )
    value = matches[0].get("msgstr")
    if not isinstance(value, str) or not value:
        raise AssertionError(
            f"{path.relative_to(ROOT)}: empty singular translation for {msgid!r}"
        )
    return value


def fail(message: str) -> None:
    raise AssertionError(message)


po_files = sorted(LOCALIZATION.rglob("*.po"))
if not po_files:
    fail("no Polish PO files found")

for path in po_files:
    language = header_value(path, "Language")
    if language != "pl":
        fail(
            f"{path.relative_to(ROOT)}: Language header must be 'pl', "
            f"found {language!r}"
        )

    plural_forms = header_value(path, "Plural-Forms")
    if plural_forms is not None:
        rel = path.relative_to(ROOT).as_posix()
        expected_nplurals = (
            4 if rel == "localization/gsconnect/pl.po" else 3
        )
        if f"nplurals={expected_nplurals}" not in plural_forms:
            fail(
                f"{rel}: expected nplurals={expected_nplurals}, "
                f"found {plural_forms!r}"
            )

expected = {
    ("localization/ding/pl.po", "Copy", None): "Kopiuj",
    ("localization/ding/pl.po", "New Folder", None): "Nowy folder",
    ("localization/just-another-search-bar/pl.po", "Preferences", None): "Preferencje",
    ("localization/ptyxis/pl.po", "Preferences", None): "Preferencje",
    # Deliberate contextual exception documented in localization/STYLE-GUIDE.md.
    ("localization/vitals/v85-completion.po", "Preferences", None): "— ustawienia",
    # Search is a section/feature noun here, not a command.
    ("localization/just-perfection/pl.po", "Search", None): "Wyszukiwanie",
    # Search is an action in Clipboard Indicator.
    ("localization/clipboard-indicator/v71-completion.po", "Search", None): "Szukaj",
}

for (rel, msgid, msgctxt), wanted in expected.items():
    path = ROOT / rel
    actual = singular_translation(path, msgid, msgctxt)
    if actual != wanted:
        fail(
            f"{rel}: {msgid!r} expected {wanted!r}, found {actual!r}"
        )

print(
    "PASS: Polish localization metadata and reviewed terminology "
    f"({len(po_files)} catalogs, {len(expected)} terminology checks)"
)
