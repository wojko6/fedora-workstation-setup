#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MANIFEST = ROOT / "gnome" / "managed-system-extensions.tsv"
INVENTORY = ROOT / "gnome" / "extensions-inventory.tsv"
SOURCE_LOCK = ROOT / "gnome" / "extensions-lock.tsv"
TREE_LOCK = ROOT / "gnome" / "extensions-tree-lock.tsv"
DISPLAY_NAMES = ROOT / "gnome" / "extension-display-names-pl.tsv"
PATCH = ROOT / "patches" / "gnome-extensions" / "ding" / "v99-desktopMenu-system-monitor.patch"
BUILDER = ROOT / "scripts" / "build-ding-v99-managed-tree.sh"
MIGRATE = ROOT / "scripts" / "install-ding-managed-system.sh"
LEGACY_INSTALL = ROOT / "scripts" / "install-ding-system-monitor-menu.sh"
VERIFY = ROOT / "scripts" / "verify-ding-system-monitor-menu.sh"
LOCALIZATIONS = ROOT / "scripts" / "install-localizations.sh"
MAIN_INSTALL = ROOT / "install.sh"
MAIN_VERIFY = ROOT / "scripts" / "verify.sh"
DING_PO = ROOT / "localization" / "ding" / "pl.po"

UUID = "ding@rastersoft.com"
VERSION = "99"
ARCHIVE_SHA = "f5f80d3371f00b7f3fd073d33c90f1c18750f006a284e76f37c1973685a33acc"
TREE_SHA = "f24e5d056ede9a74436eeaff2aa3fb2d6e3e7758f0fa5cd21f69db49f5446c7e"
SYSTEM_PATH = "/usr/local/share/gnome-shell/extensions/ding@rastersoft.com"

with MANIFEST.open(encoding="utf-8", newline="") as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))

matches = [row for row in rows if row.get("uuid") == UUID]
if len(matches) != 1:
    raise SystemExit("FAIL: managed-system DING manifest row missing or duplicated")

row = matches[0]
expected = {
    "runtime_version": VERSION,
    "shell_major": "50",
    "archive_sha256": ARCHIVE_SHA,
    "managed_tree_sha256": TREE_SHA,
    "location": SYSTEM_PATH,
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(
            f"FAIL: managed-system DING {key} mismatch: "
            f"expected {value!r}, found {row.get(key)!r}"
        )

inventory = INVENTORY.read_text(encoding="utf-8")
inventory_line = (
    f"{UUID}\tDesktop Icons NG (DING)\t{VERSION}\t50\t"
    "https://gitlab.com/rastersoft/desktop-icons-ng\t"
    f"{SYSTEM_PATH}"
)
if inventory_line not in inventory:
    raise SystemExit("FAIL: DING v99 managed-system inventory row missing")

for path in (SOURCE_LOCK, TREE_LOCK, DISPLAY_NAMES):
    if any(
        line.startswith(f"{UUID}\t")
        for line in path.read_text(encoding="utf-8").splitlines()
    ):
        raise SystemExit(
            f"FAIL: system-managed DING must not remain in per-user manifest {path.name}"
        )

patch_text = PATCH.read_text(encoding="utf-8")
for phrase in (
    "open-system-monitor",
    "org.gnome.SystemMonitor.desktop",
    "_('System Monitor')",
    "@@ -118,6 +118,14 @@",
    "@@ -224,6 +232,7 @@",
):
    if phrase not in patch_text:
        raise SystemExit(f"FAIL: exact DING v99 patch contract missing: {phrase}")

builder = BUILDER.read_text(encoding="utf-8")
for phrase in (
    ARCHIVE_SHA,
    "PRISTINE_METADATA_SHA256",
    "PRISTINE_MENU_SHA256",
    "PRISTINE_PL_MO_SHA256",
    "--fuzz=0",
    "grep -Eqi 'offset|fuzz'",
    "Polish DING menu coverage",
    "NO_LIVE_MUTATION=YES",
):
    if phrase not in builder:
        raise SystemExit(f"FAIL: DING v99 builder contract missing: {phrase}")

migration = MIGRATE.read_text(encoding="utf-8")
for phrase in (
    "managed-system-extensions.tsv",
    "build-ding-v99-managed-tree.sh",
    "=== BACKUP CURRENT STATE ===",
    "rollback()",
    "ROLLBACK=COMPLETED",
    "/usr/local/share/gnome-shell/extensions/",
    "extension-updates",
    'normalized="${entry%/}"',
    '[[ "$normalized" == "/usr/local/share" ]]',
    "sudo chown -R root:root",
    "MIGRATION_REQUIRED=YES",
):
    if phrase not in migration:
        raise SystemExit(f"FAIL: DING migration contract missing: {phrase}")

verify = VERIFY.read_text(encoding="utf-8")
for phrase in (
    "managed-system-extensions.tsv",
    'normalized="${entry%/}"',
    '[[ "$normalized" == "/usr/local/share" ]]',
    "per-user DING copy still exists",
    "pending per-user DING update still exists",
    "root:root",
    "managed tree integrity drift",
    "Monitor systemu",
    "GNOME runtime still resolves DING",
):
    if phrase not in verify:
        raise SystemExit(f"FAIL: DING managed verifier contract missing: {phrase}")

legacy = LEGACY_INSTALL.read_text(encoding="utf-8")
if "install-ding-managed-system.sh" not in legacy:
    raise SystemExit("FAIL: legacy DING installer does not delegate to managed-system installer")

localizations = LOCALIZATIONS.read_text(encoding="utf-8")
if '"ding@rastersoft.com"' in localizations:
    raise SystemExit("FAIL: generic localization installer must not mutate system-managed DING")

main_install = MAIN_INSTALL.read_text(encoding="utf-8")
managed_pos = main_install.find("scripts/install-ding-managed-system.sh")
user_pos = main_install.find("scripts/install-extensions.sh")
if managed_pos < 0 or user_pos < 0 or managed_pos >= user_pos:
    raise SystemExit(
        "FAIL: managed DING must be installed before ordinary user extensions"
    )

main_verify = MAIN_VERIFY.read_text(encoding="utf-8")
if "=== DING V99 MANAGED SYSTEM EXTENSION ===" not in main_verify:
    raise SystemExit("FAIL: full verifier does not expose managed DING acceptance")
if 'verify_translation \\\n  "ding"' in main_verify:
    raise SystemExit("FAIL: generic verifier must not target system-managed DING catalog")

po_text = DING_PO.read_text(encoding="utf-8")
required_translations = {
    "Arrange Icons": "Rozmieść ikony",
    "Arrange By...": "Sortuj według...",
    "Show Desktop in Files": "Wyświetl pulpit w menedżerze plików",
    "Change Background…": "Zmień tło…",
    "Desktop Icons Settings": "Ustawienia ikon pulpitu",
    "Display Settings": "Ustawienia ekranu",
    "System Monitor": "Monitor systemu",
}
for msgid, msgstr in required_translations.items():
    needle = f'msgid "{msgid}"\nmsgstr "{msgstr}"'
    if needle not in po_text:
        raise SystemExit(f"FAIL: DING Polish catalog missing: {msgid} -> {msgstr}")

print("PASS: DING v99 source and final managed-tree pins are explicit")
print("PASS: DING moved out of per-user source/tree/display-name manifests")
print("PASS: v99 builder is exact/fail-closed and non-mutating")
print("PASS: migration normalizes trailing slashes in XDG_DATA_DIRS")
print("PASS: migration is backup/rollback aware and clears stale per-user updates")
print("PASS: verifier enforces system scope, ownership, tree integrity and Polish UI")
print("PASS: restore ordering prevents ordinary extension installer from replacing DING")
print("=== DING MANAGED-SYSTEM TESTS: PASS ===")
