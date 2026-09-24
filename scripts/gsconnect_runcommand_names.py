#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

APP_SCHEMA = "org.gnome.Shell.Extensions.GSConnect"
RUNCOMMAND_SCHEMA = "org.gnome.Shell.Extensions.GSConnect.Plugin.RunCommand"
ROOT_PATH = "/org/gnome/shell/extensions/gsconnect/"

# Only factory entries with the exact UUID, English name and command are migrated.
# The command string is never translated or otherwise changed.
DEFAULT_COMMANDS = {
    "lock": ("Lock", "Zablokuj", "xdg-screensaver lock"),
    "logout": ("Log Out", "Wyloguj", "gnome-session-quit --logout --no-prompt"),
    "poweroff": ("Power Off", "Wyłącz", "systemctl poweroff"),
    "restart": ("Restart", "Uruchom ponownie", "systemctl reboot"),
    "suspend": ("Suspend", "Uśpij", "systemctl suspend"),
}


def load_gi():
    try:
        from gi.repository import Gio, GLib
    except ImportError as exc:
        raise SystemExit(f"FAIL: PyGObject/Gio unavailable: {exc}")
    return Gio, GLib


def schema_source(schema_dir: Path, Gio):
    if not schema_dir.is_dir():
        raise SystemExit(f"FAIL: GSConnect schema directory missing: {schema_dir}")

    return Gio.SettingsSchemaSource.new_from_directory(
        str(schema_dir),
        Gio.SettingsSchemaSource.get_default(),
        False,
    )


def settings_for(source, schema_id: str, path: str, Gio):
    schema = source.lookup(schema_id, True)
    if schema is None:
        raise SystemExit(f"FAIL: GSConnect GSettings schema missing: {schema_id}")
    return Gio.Settings.new_full(schema, None, path)


def command_settings(source, device_id: str, Gio):
    schema = source.lookup(RUNCOMMAND_SCHEMA, True)
    if schema is None:
        raise SystemExit(
            f"FAIL: GSConnect GSettings schema missing: {RUNCOMMAND_SCHEMA}"
        )
    path = f"{ROOT_PATH}device/{device_id}/plugin/runcommand/"
    return Gio.Settings.new_full(schema, None, path)


def _deep_unpack(value):
    """Recursively convert GLib.Variant containers to plain Python values."""
    unpack = getattr(value, "unpack", None)
    if callable(unpack):
        return _deep_unpack(unpack())

    if isinstance(value, dict):
        return {
            key: _deep_unpack(item)
            for key, item in value.items()
        }

    if isinstance(value, (list, tuple)):
        return type(value)(_deep_unpack(item) for item in value)

    return value


def unpack_commands(settings) -> dict[str, dict[str, str]]:
    commands = _deep_unpack(settings.get_value("command-list"))
    if not isinstance(commands, dict):
        raise SystemExit(
            "FAIL: unexpected GSConnect command-list container type: "
            f"{type(commands).__name__}"
        )

    result: dict[str, dict[str, str]] = {}

    for uuid, entry in commands.items():
        if not isinstance(entry, dict):
            raise SystemExit(
                f"FAIL: unexpected GSConnect command-list entry type for {uuid!r}"
            )
        name = entry.get("name")
        command = entry.get("command")
        if not isinstance(name, str) or not isinstance(command, str):
            raise SystemExit(
                f"FAIL: malformed GSConnect command-list entry for {uuid!r}"
            )
        result[uuid] = {"name": name, "command": command}

    return result


def pack_commands(commands: dict[str, dict[str, str]], GLib):
    packed = {
        uuid: GLib.Variant(
            "a{ss}",
            {
                "name": entry["name"],
                "command": entry["command"],
            },
        )
        for uuid, entry in commands.items()
    }
    return GLib.Variant("a{sv}", packed)


def inspect_or_apply(schema_dir: Path, apply: bool) -> int:
    Gio, GLib = load_gi()
    source = schema_source(schema_dir, Gio)
    root = settings_for(source, APP_SCHEMA, ROOT_PATH, Gio)
    devices = root.get_strv("devices")

    inspected = 0
    localized = 0
    migrated = 0
    preserved_custom = 0
    english_defaults = 0

    for device_id in devices:
        settings = command_settings(source, device_id, Gio)
        commands = unpack_commands(settings)
        changed = False

        for uuid, (english, polish, expected_command) in DEFAULT_COMMANDS.items():
            entry = commands.get(uuid)
            if entry is None or entry["command"] != expected_command:
                continue

            inspected += 1

            if entry["name"] == polish:
                localized += 1
                continue

            if entry["name"] == english:
                english_defaults += 1
                if apply:
                    # Only the user-visible name is changed. Preserve the exact
                    # command line, UUID and every unrelated/custom command.
                    entry["name"] = polish
                    migrated += 1
                    changed = True
                continue

            # A user-supplied rename of a factory command is user-owned state.
            preserved_custom += 1

        if apply and changed:
            before_commands = {
                uuid: entry["command"] for uuid, entry in commands.items()
            }
            settings.set_value("command-list", pack_commands(commands, GLib))
            after = unpack_commands(settings)
            after_commands = {
                uuid: entry["command"] for uuid, entry in after.items()
            }
            if before_commands != after_commands:
                raise SystemExit(
                    "FAIL: GSConnect RunCommand migration changed a command line"
                )

    if apply:
        Gio.Settings.sync()
        print(
            "RunCommand names: "
            f"inspected={inspected} migrated={migrated} "
            f"already-localized={localized} preserved-custom={preserved_custom}"
        )
        return 0

    if english_defaults:
        print(
            "FAIL: GSConnect factory RunCommand names remain in English: "
            f"{english_defaults}",
            file=sys.stderr,
        )
        return 1

    print(
        "RunCommand names verified: "
        f"inspected={inspected} localized={localized} "
        f"preserved-custom={preserved_custom}"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Localize GSConnect factory RunCommand display names without "
            "changing command lines."
        )
    )
    parser.add_argument("mode", choices=("apply", "verify"))
    parser.add_argument("--schema-dir", required=True)
    args = parser.parse_args()

    return inspect_or_apply(
        Path(args.schema_dir).expanduser(),
        apply=args.mode == "apply",
    )


if __name__ == "__main__":
    raise SystemExit(main())
