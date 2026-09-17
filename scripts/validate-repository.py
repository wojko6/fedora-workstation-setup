#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENABLED = ROOT / "gnome" / "enabled-extensions.txt"
INVENTORY = ROOT / "gnome" / "extensions-inventory.tsv"

EXPECTED_HEADER = ["uuid", "name", "version", "shell_versions", "url", "location"]
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


enabled = load_enabled()
header, rows = load_inventory()

if header and header != EXPECTED_HEADER:
    fail(f"unexpected inventory header: {header!r}")

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

for uuid in enabled:
    if uuid not in inventory_by_uuid:
        fail(f"enabled extension missing from inventory: {uuid}")

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
print("PASS: enabled extension list and inventory are internally consistent")
print("PASS: rejected/conflicting extensions are absent from desired state")
print("PASS: user extension pins and portable inventory paths are valid")
