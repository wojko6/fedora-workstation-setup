#!/usr/bin/env python3
"""Static fixtures for the Ptyxis desktop-action localization patcher."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "ptyxis_desktop_actions.py"

spec = importlib.util.spec_from_file_location("ptyxis_desktop_actions", MODULE_PATH)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: unable to load Ptyxis desktop-action helper")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
patch_text = module.patch_text

BASE = """[Desktop Entry]
Name=Terminal
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
    "Name[pl]=Nowe okno",
    "Name[pl]=Nowa karta",
    "Name[pl]=Preferencje",
)
for line in expected_lines:
    assert patched.count(line) == 1, line

for line in (
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
    BASE.replace("Exec=ptyxis --tab", "Exec=ptyxis --wrong"),
    "changed Exec",
)
expect_failure(
    BASE.replace("Name=Preferences", "Name=Settings"),
    "changed default Name",
)
expect_failure(
    BASE.replace("Actions=new-window;new-tab;preferences;", "Actions=new-window;new-tab;"),
    "changed action list",
)
expect_failure(
    BASE.replace(
        "[Desktop Action new-window]\n",
        "[Desktop Action new-window]\nName[pl]=Błędna nazwa\n",
    ),
    "pre-existing Polish action name",
)

print("PASS: Ptyxis desktop-action localization fixtures")
