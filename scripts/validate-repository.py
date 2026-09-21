#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
import stat
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENABLED = ROOT / "gnome" / "enabled-extensions.txt"
INVENTORY = ROOT / "gnome" / "extensions-inventory.tsv"
TREE_LOCK = ROOT / "gnome" / "extensions-tree-lock.tsv"
LOCK = ROOT / "gnome" / "extensions-lock.tsv"
WEATHER_LOCATIONS_EXAMPLE = ROOT / "gnome" / "weather-locations.example.tsv"
INSTALLER = ROOT / "install.sh"
RPM_REQUIRED = ROOT / "packages" / "rpm.txt"
RPM_ABSENT = ROOT / "packages" / "rpm-absent.txt"

EXPECTED_HEADER = ["uuid", "name", "version", "shell_versions", "url", "location"]
EXPECTED_LOCK_HEADER = [
    "uuid",
    "runtime_version",
    "source",
    "source_ref",
    "sha256",
]
EXPECTED_TREE_LOCK_HEADER = ["uuid", "runtime_version", "tree_sha256"]
REJECTED_EXTENSIONS = {
    "mediacontrols@cliffniff.github.com": "rejected for the GNOME 50 baseline",
    "dash2dock-lite@icedman.github.com": "conflicts with the canonical Dhruva dock",
}
USER_PREFIX = "~/.local/share/gnome-shell/extensions/"
SYSTEM_PREFIX = "/usr/share/gnome-shell/extensions/"

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def load_enabled() -> list[str]:
    if not ENABLED.is_file():
        fail(f"missing {ENABLED.relative_to(ROOT)}")
        return []

    items: list[str] = []
    for raw in ENABLED.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        items.append(line)
    return items


def load_inventory() -> tuple[list[str], list[dict[str, str]]]:
    if not INVENTORY.is_file():
        fail(f"missing {INVENTORY.relative_to(ROOT)}")
        return [], []

    with INVENTORY.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        header = reader.fieldnames or []
        rows = [dict(row) for row in reader]
    return header, rows


def load_lock() -> tuple[list[str], list[dict[str, str]]]:
    if not LOCK.is_file():
        fail(f"missing {LOCK.relative_to(ROOT)}")
        return [], []

    with LOCK.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        header = reader.fieldnames or []
        rows = [dict(row) for row in reader]
    return header, rows


def load_tree_lock() -> tuple[list[str], list[dict[str, str]]]:
    if not TREE_LOCK.is_file():
        fail(f"missing {TREE_LOCK.relative_to(ROOT)}")
        return [], []

    with TREE_LOCK.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        header = reader.fieldnames or []
        rows = [dict(row) for row in reader]
    return header, rows


def validate_entrypoints() -> None:
    if not INSTALLER.is_file():
        fail("missing install.sh")
        return

    mode = INSTALLER.stat().st_mode
    if not mode & stat.S_IXUSR:
        fail("install.sh must be executable by its owner (git mode 100755)")


def validate_weather_locations() -> None:
    if not WEATHER_LOCATIONS_EXAMPLE.is_file():
        fail(f"missing {WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}")
        return

    seen_names: set[str] = set()

    with WEATHER_LOCATIONS_EXAMPLE.open(encoding="utf-8", newline="") as fh:
        reader = csv.reader(fh, delimiter="\t")
        for lineno, row in enumerate(reader, start=1):
            if not row or not row[0].strip() or row[0].lstrip().startswith("#"):
                continue

            if len(row) != 3:
                fail(
                    f"{WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}:{lineno}: "
                    "expected name, latitude, longitude"
                )
                continue

            name = row[0].strip()
            if not name:
                fail(
                    f"{WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}:{lineno}: "
                    "location name is empty"
                )
                continue

            if name in seen_names:
                fail(
                    f"{WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}:{lineno}: "
                    f"duplicate weather location name: {name}"
                )
            seen_names.add(name)

            try:
                latitude = float(row[1])
                longitude = float(row[2])
            except ValueError:
                fail(
                    f"{WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}:{lineno}: "
                    "latitude/longitude must be decimal numbers"
                )
                continue

            if not -90.0 <= latitude <= 90.0:
                fail(
                    f"{WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}:{lineno}: "
                    f"latitude out of range: {latitude}"
                )

            if not -180.0 <= longitude <= 180.0:
                fail(
                    f"{WEATHER_LOCATIONS_EXAMPLE.relative_to(ROOT)}:{lineno}: "
                    f"longitude out of range: {longitude}"
                )


def load_package_manifest(path: Path) -> list[str]:
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")
        return []

    items: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        items.append(line)
    return items


required_rpms = load_package_manifest(RPM_REQUIRED)
absent_rpms = load_package_manifest(RPM_ABSENT)

for package, count in Counter(required_rpms).items():
    if count != 1:
        fail(f"duplicate required RPM: {package} ({count} entries)")

for package, count in Counter(absent_rpms).items():
    if count != 1:
        fail(f"duplicate absent RPM: {package} ({count} entries)")

for package in sorted(set(required_rpms) & set(absent_rpms)):
    fail(f"RPM cannot be both required and absent: {package}")


enabled = load_enabled()
header, rows = load_inventory()
lock_header, lock_rows = load_lock()
tree_lock_header, tree_lock_rows = load_tree_lock()
validate_weather_locations()
validate_entrypoints()

if header and header != EXPECTED_HEADER:
    fail(f"unexpected inventory header: {header!r}")

if lock_header and lock_header != EXPECTED_LOCK_HEADER:
    fail(f"unexpected extension lock header: {lock_header!r}")

if tree_lock_header and tree_lock_header != EXPECTED_TREE_LOCK_HEADER:
    fail(f"unexpected extension tree-lock header: {tree_lock_header!r}")

for uuid, count in Counter(enabled).items():
    if count != 1:
        fail(f"duplicate enabled extension: {uuid} ({count} entries)")

for uuid, reason in REJECTED_EXTENSIONS.items():
    if uuid in enabled:
        fail(f"rejected extension present in desired state: {uuid} ({reason})")

inventory_uuids = [row.get("uuid", "").strip() for row in rows]
for uuid, count in Counter(inventory_uuids).items():
    if not uuid:
        fail("inventory contains an empty UUID")
    elif count != 1:
        fail(f"duplicate inventory UUID: {uuid} ({count} rows)")

inventory_by_uuid = {row.get("uuid", "").strip(): row for row in rows if row.get("uuid", "").strip()}

lock_uuids = [row.get("uuid", "").strip() for row in lock_rows]

for uuid, count in Counter(lock_uuids).items():
    if not uuid:
        fail("extension lock contains an empty UUID")
    elif count != 1:
        fail(f"duplicate extension lock UUID: {uuid} ({count} rows)")

for row in lock_rows:
    uuid = row.get("uuid", "").strip()
    runtime_version = row.get("runtime_version", "").strip()
    source = row.get("source", "").strip()
    source_ref = row.get("source_ref", "").strip()
    sha256 = row.get("sha256", "").strip()

    if not uuid:
        continue

    inventory_row = inventory_by_uuid.get(uuid)

    if inventory_row is None:
        fail(f"extension lock UUID missing from inventory: {uuid}")
        continue

    if uuid not in enabled:
        fail(f"extension lock UUID is not in enabled desired state: {uuid}")

    inventory_version = inventory_row.get("version", "").strip()
    if runtime_version != inventory_version:
        fail(
            f"extension lock runtime mismatch: {uuid}: "
            f"lock={runtime_version!r} inventory={inventory_version!r}"
        )

    location = inventory_row.get("location", "").strip()
    if not location.startswith(USER_PREFIX):
        fail(f"extension lock must target a user extension: {uuid}")

    if source == "github-commit":
        if not re.fullmatch(r"[0-9a-fA-F]{40}", source_ref):
            fail(f"invalid GitHub commit pin: {uuid}: {source_ref!r}")

        url = inventory_row.get("url", "").strip()
        if not url.startswith("https://github.com/"):
            fail(
                f"GitHub commit source requires GitHub inventory URL: "
                f"{uuid}: {url!r}"
            )

        if sha256 != "-":
            fail(
                f"GitHub commit SHA-256 field must be '-': "
                f"{uuid}: {sha256!r}"
            )

    elif source == "ego":
        if source_ref != "-":
            fail(
                f"EGO lock source_ref must be '-': "
                f"{uuid}: {source_ref!r}"
            )

        if not re.fullmatch(r"[0-9a-f]{64}", sha256):
            fail(
                f"invalid EGO SHA-256 pin: "
                f"{uuid}: {sha256!r}"
            )

    else:
        fail(
            f"unsupported extension lock source: "
            f"{uuid}: {source!r}"
        )

lock_uuid_set = set(lock_uuids)

tree_lock_uuids = [row.get("uuid", "").strip() for row in tree_lock_rows]
for uuid, count in Counter(tree_lock_uuids).items():
    if not uuid:
        fail("extension tree lock contains an empty UUID")
    elif count != 1:
        fail(f"duplicate extension tree-lock UUID: {uuid} ({count} rows)")

tree_lock_uuid_set = set(tree_lock_uuids)

for row in tree_lock_rows:
    uuid = row.get("uuid", "").strip()
    runtime_version = row.get("runtime_version", "").strip()
    tree_sha256 = row.get("tree_sha256", "").strip()

    if not uuid:
        continue

    inventory_row = inventory_by_uuid.get(uuid)
    if inventory_row is None:
        fail(f"extension tree-lock UUID missing from inventory: {uuid}")
        continue

    if uuid not in enabled:
        fail(f"extension tree-lock UUID is not in enabled desired state: {uuid}")

    location = inventory_row.get("location", "").strip()
    if not location.startswith(USER_PREFIX):
        fail(f"extension tree lock must target a user extension: {uuid}")

    inventory_version = inventory_row.get("version", "").strip()
    if runtime_version != inventory_version:
        fail(
            f"extension tree-lock runtime mismatch: {uuid}: "
            f"lock={runtime_version!r} inventory={inventory_version!r}"
        )

    if not re.fullmatch(r"[0-9a-f]{64}", tree_sha256):
        fail(
            f"invalid extension tree SHA-256: "
            f"{uuid}: {tree_sha256!r}"
        )

for uuid in enabled:
    if uuid not in inventory_by_uuid:
        fail(f"enabled extension missing from inventory: {uuid}")
        continue

    inventory_row = inventory_by_uuid[uuid]
    location = inventory_row.get("location", "").strip()

    if location.startswith(USER_PREFIX) and uuid not in lock_uuid_set:
        fail(
            f"enabled user extension missing source lock: {uuid}"
        )

    if location.startswith(USER_PREFIX) and uuid not in tree_lock_uuid_set:
        fail(
            f"enabled user extension missing tree-integrity lock: {uuid}"
        )

for row in rows:
    uuid = row.get("uuid", "").strip()
    name = row.get("name", "").strip()
    version = row.get("version", "").strip()
    shell_versions = row.get("shell_versions", "").strip()
    url = row.get("url", "").strip()
    location = row.get("location", "").strip()

    if not uuid:
        continue
    if not name:
        fail(f"inventory name missing: {uuid}")
    if not shell_versions:
        fail(f"shell_versions missing: {uuid}")
    else:
        for value in shell_versions.split(","):
            if not value.isdigit():
                fail(f"invalid shell version {value!r}: {uuid}")
    if not url.startswith("https://"):
        fail(f"inventory URL must be HTTPS: {uuid}: {url!r}")

    if "/home/" in location:
        fail(f"machine-specific home path leaked into inventory: {uuid}: {location}")

    if location.startswith(USER_PREFIX):
        if not version.isdigit():
            fail(f"user extension must have a numeric runtime version pin: {uuid}: {version!r}")
        if location != f"{USER_PREFIX}{uuid}":
            fail(f"unexpected user extension location: {uuid}: {location}")
    elif location.startswith(SYSTEM_PREFIX):
        if location != f"{SYSTEM_PREFIX}{uuid}":
            fail(f"unexpected system extension location: {uuid}: {location}")
    else:
        fail(f"unsupported inventory location: {uuid}: {location!r}")

if errors:
    print("=== REPOSITORY CONSISTENCY: FAIL ===")
    for message in errors:
        print(f"FAIL: {message}")
    print(f"FAILURES={len(errors)}")
    sys.exit(1)

print("=== REPOSITORY CONSISTENCY: PASS ===")
print(f"enabled_extensions={len(enabled)}")
print(f"inventory_rows={len(rows)}")
print(f"extension_lock_rows={len(lock_rows)}")
print(f"extension_tree_lock_rows={len(tree_lock_rows)}")
print("PASS: enabled extension list and inventory are internally consistent")
print("PASS: extension source locks are internally consistent")
print("PASS: extension tree-integrity locks are complete and internally consistent")
print("PASS: rejected/conflicting extensions are absent from desired state")
print("PASS: user extension pins and portable inventory paths are valid")
print("PASS: public GNOME Weather location example is structurally valid")
print("PASS: required and absent RPM manifests are internally consistent")
