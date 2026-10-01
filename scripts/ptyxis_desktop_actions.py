#!/usr/bin/env python3
"""Deterministically add audited Polish Ptyxis desktop metadata and actions."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ACTIONS_LINE = "Actions=new-window;new-tab;preferences;"

MAIN_FIELDS = (
    (
        "Comment",
        "A container-oriented terminal for GNOME",
        "Terminal GNOME przeznaczony do pracy z kontenerami",
    ),
    (
        "GenericName",
        "Terminal",
        "Terminal",
    ),
)

ACTIONS = {
    "new-window": ("New Window", "Nowe okno", "ptyxis --new-window"),
    "new-tab": ("New Tab", "Nowa karta", "ptyxis --tab"),
    "preferences": ("Preferences", "Preferencje", "ptyxis --preferences"),
}


def patch_main_section(text: str) -> str:
    pattern = re.compile(
        r"(?ms)^\[Desktop Entry\]\n"
        r"(?P<body>.*?)(?=^\[|\Z)"
    )

    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise ValueError(
            f"expected exactly one [Desktop Entry] section, found {len(matches)}"
        )

    match = matches[0]
    body = match.group("body")

    for key, english_value, polish_value in MAIN_FIELDS:
        if re.search(
            rf"(?m)^{re.escape(key)}\[pl(?:_[^]]+)?\]=",
            body,
        ):
            raise ValueError(
                f"audited pristine Desktop Entry already contains Polish {key}"
            )

        default_line = f"{key}={english_value}"
        localized_line = f"{key}[pl]={polish_value}"

        if body.splitlines().count(default_line) != 1:
            raise ValueError(
                f"Desktop Entry does not contain exactly one {default_line!r}"
            )

        marker = default_line + "\n"
        replacement = default_line + "\n" + localized_line + "\n"

        if marker in body:
            body = body.replace(marker, replacement, 1)
        elif body.endswith(default_line):
            body = body[: -len(default_line)] + (
                default_line + "\n" + localized_line
            )
        else:
            raise ValueError(f"unable to patch {key} in Desktop Entry")

    return (
        text[: match.start("body")]
        + body
        + text[match.end("body") :]
    )


def patch_actions(text: str) -> str:
    if text.count(ACTIONS_LINE) != 1:
        raise ValueError(
            f"expected exactly one audited actions line: {ACTIONS_LINE}"
        )

    result = text

    for action, (english_name, polish_name, exec_line) in ACTIONS.items():
        pattern = re.compile(
            rf"(?ms)^\[Desktop Action {re.escape(action)}\]\n"
            rf"(?P<body>.*?)(?=^\[|\Z)"
        )

        matches = list(pattern.finditer(result))
        if len(matches) != 1:
            raise ValueError(
                f"expected exactly one [Desktop Action {action}] section, "
                f"found {len(matches)}"
            )

        match = matches[0]
        body = match.group("body")

        if re.search(r"(?m)^Name\[pl(?:_[^]]+)?\]=", body):
            raise ValueError(
                f"audited pristine section {action} already contains a Polish Name"
            )

        default_name = f"Name={english_name}"
        expected_exec = f"Exec={exec_line}"

        if body.splitlines().count(default_name) != 1:
            raise ValueError(
                f"section {action} does not contain exactly one {default_name!r}"
            )

        if body.splitlines().count(expected_exec) != 1:
            raise ValueError(
                f"section {action} does not contain exactly one {expected_exec!r}"
            )

        patched_body = body.replace(
            default_name + "\n",
            f"Name[pl]={polish_name}\n{default_name}\n",
            1,
        )

        if patched_body == body:
            if not body.endswith(default_name):
                raise ValueError(f"unable to patch Name in section {action}")

            patched_body = body[: -len(default_name)] + (
                f"Name[pl]={polish_name}\n{default_name}"
            )

        result = (
            result[: match.start("body")]
            + patched_body
            + result[match.end("body") :]
        )

    return result


def patch_text(text: str) -> str:
    return patch_actions(patch_main_section(text))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = args.input.read_text(encoding="utf-8")

    try:
        patched = patch_text(source)
    except ValueError as exc:
        parser.error(str(exc))

    args.output.write_text(patched, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
