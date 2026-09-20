#!/usr/bin/env python3
"""Manage reviewed custom GNOME Weather locations.

The GNOME Weather "locations" key is an array of libgweather-serialized
GVariants.  Do not construct that private serialization format manually:
libgweather owns the format and may change it between releases.
"""

from __future__ import annotations

import argparse
import csv
import sys
from dataclasses import dataclass
from pathlib import Path


SCHEMA_CANDIDATES = (
    "org.gnome.Weather",
    "org.gnome.Weather.Application",
)


@dataclass(frozen=True)
class LocationSpec:
    name: str
    latitude_deg: float
    longitude_deg: float


def fail(message: str) -> "NoReturn":
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_specs(path: Path) -> list[LocationSpec]:
    if not path.is_file():
        fail(f"weather location config missing: {path}")

    specs: list[LocationSpec] = []
    seen_names: set[str] = set()

    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for lineno, row in enumerate(reader, start=1):
            if not row or not row[0].strip() or row[0].lstrip().startswith("#"):
                continue
            if len(row) != 3:
                fail(f"{path}:{lineno}: expected 3 tab-separated fields")

            name = row[0].strip()
            try:
                latitude = float(row[1])
                longitude = float(row[2])
            except ValueError:
                fail(f"{path}:{lineno}: latitude/longitude must be decimal numbers")

            if not (-90.0 <= latitude <= 90.0):
                fail(f"{path}:{lineno}: invalid latitude: {latitude}")
            if not (-180.0 <= longitude <= 180.0):
                fail(f"{path}:{lineno}: invalid longitude: {longitude}")
            if name in seen_names:
                fail(f"{path}:{lineno}: duplicate location name: {name}")

            seen_names.add(name)
            specs.append(LocationSpec(name, latitude, longitude))

    if not specs:
        fail(f"no weather locations defined in {path}")

    return specs


def load_gnome_api():
    try:
        import gi
    except ImportError:
        fail("PyGObject is unavailable (python3-gobject is required)")

    try:
        gi.require_version("GWeather", "4.0")
        from gi.repository import Gio, GLib, GWeather
    except (ImportError, ValueError) as exc:
        fail(f"libgweather 4 introspection is unavailable: {exc}")

    return Gio, GLib, GWeather


def open_weather_settings(Gio):
    source = Gio.SettingsSchemaSource.get_default()
    if source is None:
        fail("GSettings schema source is unavailable")

    for schema_id in SCHEMA_CANDIDATES:
        schema = source.lookup(schema_id, True)
        if schema is None:
            continue
        if not schema.has_key("locations"):
            continue

        settings = Gio.Settings.new_full(schema, None, None)
        value = settings.get_value("locations")
        if value.get_type_string() != "av":
            fail(
                f"{schema_id}: unexpected locations type "
                f"{value.get_type_string()!r}; expected 'av'"
            )
        return schema_id, settings

    fail(
        "GNOME Weather GSettings schema with a 'locations' key was not found; "
        "install/open GNOME Weather first"
    )


def create_location(GWeather, spec: LocationSpec):
    # libgweather 4 public API expects latitude/longitude in decimal degrees.
    return GWeather.Location.new_detached(
        spec.name,
        None,
        spec.latitude_deg,
        spec.longitude_deg,
    )


def unwrap_location_variant(value):
    if value.get_type_string() == "v":
        return value.get_variant()
    return value


def variant_equal(left, right) -> bool:
    try:
        return bool(left.equal(right))
    except AttributeError:
        return left.print_(True) == right.print_(True)


def contains_serialized_location(current, serialized) -> bool:
    for index in range(current.n_children()):
        existing = unwrap_location_variant(current.get_child_value(index))
        if variant_equal(existing, serialized):
            return True
    return False


def deserialize_location(world, value):
    try:
        return world.deserialize(unwrap_location_variant(value))
    except Exception:
        return None


def remove_locations_by_name(GLib, world, current, name: str):
    builder = GLib.VariantBuilder.new(GLib.VariantType.new("av"))
    removed = 0

    for index in range(current.n_children()):
        child = current.get_child_value(index)
        location = deserialize_location(world, child)

        matches = False
        if location is not None:
            candidates = {
                value
                for value in (
                    location.get_name(),
                    location.get_english_name(),
                    location.get_city_name(),
                )
                if value
            }
            matches = name in candidates

        if matches:
            removed += 1
            continue

        builder.add_value(child)

    return builder.end(), removed


def find_locations_by_name(world, current, name: str):
    matches = []
    for index in range(current.n_children()):
        location = deserialize_location(world, current.get_child_value(index))
        if location is None:
            continue
        candidates = {
            value
            for value in (
                location.get_name(),
                location.get_english_name(),
                location.get_city_name(),
            )
            if value
        }
        if name in candidates:
            matches.append(location)
    return matches


def append_serialized_location(GLib, current, serialized):
    builder = GLib.VariantBuilder.new(GLib.VariantType.new("av"))
    for index in range(current.n_children()):
        builder.add_value(current.get_child_value(index))
    builder.add_value(GLib.Variant.new_variant(serialized))
    return builder.end()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install or verify reviewed custom GNOME Weather locations."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true", help="add missing locations")
    mode.add_argument("--verify", action="store_true", help="verify locations only")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "gnome" / "weather-locations.local.tsv",
        help="private tab-separated location config (gitignored by default)",
    )
    args = parser.parse_args()

    specs = load_specs(args.config)
    Gio, GLib, GWeather = load_gnome_api()
    schema_id, settings = open_weather_settings(Gio)

    world = GWeather.Location.get_world()
    if world is None:
        fail("libgweather world database could not be loaded")

    current = settings.get_value("locations")
    changed = False

    for spec in specs:
        location = create_location(GWeather, spec)
        serialized = location.serialize()

        if args.verify:
            matches = find_locations_by_name(world, current, spec.name)
            if len(matches) != 1:
                print(
                    f"FAIL: expected exactly one GNOME Weather location named "
                    f"{spec.name!r}, found {len(matches)}",
                    file=sys.stderr,
                )
                return 1

            # Do not compare private serialized GVariant bytes. libgweather only
            # guarantees that serialization can be deserialized to an equivalent
            # location; GNOME Weather may legitimately normalize the stored
            # representation. Compare the geographical location through the
            # public libgweather API instead.
            if not matches[0].equal(location):
                print(
                    f"FAIL: GNOME Weather location has wrong geographical state: "
                    f"{spec.name} ({spec.latitude_deg:.6f}, "
                    f"{spec.longitude_deg:.6f})",
                    file=sys.stderr,
                )
                return 1

            print(
                f"PASS: GNOME Weather location present exactly once and "
                f"geographically matches repository: {spec.name} "
                f"({spec.latitude_deg:.6f}, {spec.longitude_deg:.6f})"
            )
            continue

        # Normalize by human-readable name, not only by serialized bytes.
        # The first implementation could leave a broken entry with the same
        # display name but different coordinates; GNOME Weather would continue
        # selecting that older first entry even after a correct one was appended.
        current, removed = remove_locations_by_name(
            GLib, world, current, spec.name
        )
        if removed:
            changed = True
            print(
                f"MIGRATED: removed {removed} existing location entr"
                f"{'y' if removed == 1 else 'ies'} named {spec.name!r}"
            )

        current = append_serialized_location(GLib, current, serialized)
        changed = True
        print(
            f"INSTALLED: GNOME Weather location: {spec.name} "
            f"({spec.latitude_deg:.6f}, {spec.longitude_deg:.6f})"
        )

    if args.apply and changed:
        if not settings.set_value("locations", current):
            fail(f"failed to update {schema_id} locations")
        Gio.Settings.sync()

    if args.apply and changed:
        current = settings.get_value("locations")
        for spec in specs:
            desired = create_location(GWeather, spec)
            matches = find_locations_by_name(world, current, spec.name)
            if len(matches) != 1 or not matches[0].equal(desired):
                fail(f"post-write verification failed for: {spec.name}")

    print(
        f"PASS: GNOME Weather custom-location {'installation' if args.apply else 'verification'} "
        f"completed using {schema_id}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
