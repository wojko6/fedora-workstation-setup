#!/usr/bin/env python3
"""Static fixtures for the Ptyxis desktop localization patcher."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "ptyxis_desktop_actions.py"

spec = importlib.util.spec_from_file_location(
    "ptyxis_desktop_actions",
    MODULE_PATH,
)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: unable to load Ptyxis desktop helper")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
patch_text = module.patch_text

BASE = """[Desktop Entry]
Name=Terminal
Comment=A container-oriented terminal for GNOME
GenericName=Terminal
Actions=new-window;new-tab;preferences;

[Desktop Action new-window]
Name[de]=Neues Fenster
Name=New Window
Exec=ptyxis --new-window

[Desktop Action new-tab]
Name[de]=Neuer Reiter
Name=New Tab
Exec=ptyxis --tab

[Desktop Action preferences]
Name[de]=Einstellungen
Name=Preferences
Exec=ptyxis --preferences
"""


def expect_failure(text: str, label: str) -> None:
    try:
        patch_text(text)
    except ValueError:
        return

    raise AssertionError(f"expected failure: {label}")


patched = patch_text(BASE)

expected_lines = (
    "Comment[pl]=Terminal GNOME przeznaczony do pracy z kontenerami",
    "GenericName[pl]=Terminal",
    "Name[pl]=Nowe okno",
    "Name[pl]=Nowa karta",
    "Name[pl]=Preferencje",
)

for line in expected_lines:
    assert patched.count(line) == 1, line

for line in (
    "Comment=A container-oriented terminal for GNOME",
    "GenericName=Terminal",
    "Exec=ptyxis --new-window",
    "Exec=ptyxis --tab",
    "Exec=ptyxis --preferences",
    "Name=New Window",
    "Name=New Tab",
    "Name=Preferences",
):
    assert patched.count(line) == 1, line

stripped = patched
for line in expected_lines:
    stripped = stripped.replace(line + "\n", "")

assert stripped == BASE

expect_failure(patched, "already-localized source")

expect_failure(
    BASE.replace(
        "Comment=A container-oriented terminal for GNOME",
        "Comment=Changed",
    ),
    "changed default Comment",
)

expect_failure(
    BASE.replace(
        "GenericName=Terminal",
        "GenericName=Terminal Emulator",
    ),
    "changed default GenericName",
)

expect_failure(
    BASE.replace("Exec=ptyxis --tab", "Exec=ptyxis --wrong"),
    "changed Exec",
)

expect_failure(
    BASE.replace("Name=Preferences", "Name=Settings"),
    "changed action Name",
)

expect_failure(
    BASE.replace(
        "Actions=new-window;new-tab;preferences;",
        "Actions=new-window;new-tab;",
    ),
    "changed action list",
)

print("PASS: Ptyxis desktop localization fixtures")
