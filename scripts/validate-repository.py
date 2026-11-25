#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
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
MANAGED_SYSTEM = ROOT / "gnome" / "managed-system-extensions.tsv"
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
EXPECTED_MANAGED_SYSTEM_HEADER = [
    "uuid",
    "runtime_version",
    "shell_major",
    "archive_sha256",
    "managed_tree_sha256",
    "location",
]
REJECTED_EXTENSIONS = {
    "mediacontrols@cliffniff.github.com": "rejected for the GNOME 50 baseline",
    "dash2dock-lite@icedman.github.com": "conflicts with the canonical Dhruva dock",
}
USER_PREFIX = "~/.local/share/gnome-shell/extensions/"
SYSTEM_PREFIX = "/usr/share/gnome-shell/extensions/"
MANAGED_SYSTEM_PREFIX = "/usr/local/share/gnome-shell/extensions/"

# Explicit contract, deliberately independent of the editable manifest.
# Update both only after reviewing the dependencies of all installer stages.
REQUIRED_STAGE_INPUTS = frozenset("""
desktop/launchers/asus-router.desktop.template
desktop/launchers/counter-strike-2.desktop
desktop/menu-localization-rpm.json
gnome/dhruva/dock-state.json
gnome/enabled-extensions.txt
gnome/extension-display-names-pl.tsv
gnome/extensions-inventory.tsv
gnome/extensions-lock.tsv
gnome/extensions-tree-lock.tsv
gnome/managed-system-extensions.tsv
gnome/settings.dconf
gnome/weather-locations.example.tsv
localization/advanced-media-controller/pl.po
localization/advanced-media-controller/v31.pot
localization/appindicator/v64-completion.po
localization/arcmenu/v74-bindtextdomain.patch
localization/arcmenu/v74-completion.po
localization/arcmenu/v74-source.json
localization/bluetooth-battery-meter/v46-budslink-completion.po
localization/blur-my-shell/v72-completion.po
localization/caffeine/v60-completion.po
localization/clipboard-indicator/v71-completion.po
localization/ddterm/v73-completion.po
localization/dhruva/pl.po
localization/ding/pl.po
localization/display-brightness-ddcutil/pl.po
localization/extension-manager/v0.6.5-completion.po
localization/gnome-tweaks/v49.0-gsettings-enums.po
localization/gsconnect/pl.po
localization/helium/v0.18.1.1-pl-completion.json
localization/just-another-search-bar/pl.po
localization/just-perfection/pl.po
localization/just-perfection/v37-additions.po
localization/monitor-smart-saver/pl.po
localization/papers/pl-overlay.po
localization/plymouth/55-polish-plymouth.conf
localization/ptyxis/pl.po
localization/space-bar/v39-replacements.json
localization/spotlight/pl.po
localization/tiling-shell/pl.po
localization/user-theme/pl.po
localization/vitals/v85-completion.po
network/check-trusted-wifi.sh
packages/flatpak.txt
packages/rpm-absent.txt
packages/rpm.txt
patches/gnome-extensions/background-logo/prefs-pl.patch
patches/gnome-extensions/blur-my-shell/pipeline-choose-row-i18n.patch
patches/gnome-extensions/blur-my-shell/pipeline-group-i18n.patch
patches/gnome-extensions/browser-switcher/indicator-pl.patch
patches/gnome-extensions/browser-switcher/menuBuilder-pl.patch
patches/gnome-extensions/dhruva/WindowThumbnailBuilder-gettext.patch
patches/gnome-extensions/dhruva/metadata-gettext.patch
patches/gnome-extensions/dhruva/src__core__FolderManager-gettext.patch
patches/gnome-extensions/dhruva/src__prefs__AboutPage-gettext.patch
patches/gnome-extensions/dhruva/src__prefs__AppearancePage-gettext.patch
patches/gnome-extensions/dhruva/src__prefs__BehaviorPage-gettext.patch
patches/gnome-extensions/dhruva/src__prefs__LayoutPage-gettext.patch
patches/gnome-extensions/dhruva/src__prefs__ModulesPage-gettext.patch
patches/gnome-extensions/dhruva/src__prefs__ResetButtons-gettext.patch
patches/gnome-extensions/dhruva/src__ui__AppGridUI-gettext.patch
patches/gnome-extensions/dhruva/src__ui__DragDrop-gettext.patch
patches/gnome-extensions/dhruva/src__ui__context-menu__AppContextMenu-gettext.patch
patches/gnome-extensions/dhruva/src__ui__context-menu__TrashActionsHandler-gettext.patch
patches/gnome-extensions/dhruva/src__ui__folder-menu__EmojiPicker-gettext.patch
patches/gnome-extensions/dhruva/src__ui__folder-menu__FolderMenuBuilder-gettext.patch
patches/gnome-extensions/dhruva/src__ui__magnifier__MagnifierFrameEngine-gettext.patch
patches/gnome-extensions/dhruva/src__ui__modules__AppGridModule-gettext.patch
patches/gnome-extensions/dhruva/src__ui__modules__DockModules-gettext.patch
patches/gnome-extensions/dhruva/src__ui__modules__SystemFoldersModule-gettext.patch
patches/gnome-extensions/dhruva/src__ui__modules__TrashModule-gettext.patch
patches/gnome-extensions/ding/v99-desktopMenu-system-monitor.patch
patches/gnome-extensions/spotlight/0001-localize-preferences-entry.patch
patches/gnome-extensions/spotlight/0002-localize-shortcut-page.patch
patches/gnome-extensions/spotlight/0003-localize-appearance-page.patch
patches/gnome-extensions/spotlight/0004-localize-about-page.patch
patches/gnome-extensions/tiling-shell/v76-editor-legend-gettext.patch
patches/gnome-extensions/user-theme/metadata-pl.patch
patches/gnome-extensions/user-theme/prefs-gettext.patch
patches/gnome-extensions/vitals/v85-values-gettext.patch
patches/gnome-tweaks/v49.0-gsettings-enum-gettext.patch
scripts/apply-space-bar-localization.py
scripts/build-ding-v99-managed-tree.sh
scripts/desktop-entry-localization.py
scripts/extension-display-names.py
scripts/extension_tree_integrity.py
scripts/generate-dhruva-emoji-pl.py
scripts/gsconnect_runcommand_names.py
scripts/helium-localization-post-transaction.sh
scripts/helium_datapack.py
scripts/install-advanced-media-controller-localization.sh
scripts/install-appindicator-localization.sh
scripts/install-arcmenu-localization.sh
scripts/install-background-logo-localization.sh
scripts/install-bluetooth-battery-meter-localization.sh
scripts/install-blur-my-shell-localization.sh
scripts/install-browser-switcher-localization.sh
scripts/install-caffeine-localization.sh
scripts/install-clipboard-indicator-localization.sh
scripts/install-ddterm-localization.sh
scripts/install-dhruva-localization.sh
scripts/install-extension-display-names.sh
scripts/install-extension-manager-localization.sh
scripts/install-gnome-tweaks-localization.sh
scripts/install-gsconnect-localization.sh
scripts/install-helium-localization.sh
scripts/install-just-perfection-localization.sh
scripts/install-papers-localization.sh
scripts/install-plymouth-localization.sh
scripts/install-preflight.sh
scripts/install-ptyxis-localization.sh
scripts/install-rpm-desktop-localizations.sh
scripts/install-space-bar-localization.sh
scripts/install-spotlight-localization.sh
scripts/install-tiling-shell-localization.sh
scripts/install-user-theme-localization.sh
scripts/install-vitals-localization.sh
scripts/manage-weather-locations.py
scripts/prepare_github_extension_metadata.py
scripts/ptyxis_desktop_actions.py
scripts/ptyxis_resource_audit.py
scripts/render-asus-launcher.py
scripts/validate-repository.py
scripts/verify-advanced-media-controller-localization.sh
scripts/verify-appindicator-localization.sh
scripts/verify-arcmenu-localization.sh
scripts/verify-bluetooth-battery-meter-localization.sh
scripts/verify-blur-my-shell-localization.sh
scripts/verify-caffeine-localization.sh
scripts/verify-clipboard-indicator-localization.sh
scripts/verify-ddterm-localization.sh
scripts/verify-extension-manager-localization.sh
scripts/verify-gnome-tweaks-localization.sh
scripts/verify-gsconnect-localization.sh
scripts/verify-helium-localization.sh
scripts/verify-repository-trust.py
scripts/verify-tiling-shell-localization.sh
scripts/verify-user-theme-localization.sh
scripts/verify-vitals-localization.sh
scripts/verify_ego_extension.py
scripts/verify_github_archive.py
security/repository-trust.json
system/dnf5/actions.d/90-helium-localization.actions
""".split())

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def input_diagnostics(function):
    def checked(*args, **kwargs):
        try:
            return function(*args, **kwargs)
        except (OSError, UnicodeError):
            fail("cannot read repository input (access or UTF-8 error)")
            return []
    return checked


@input_diagnostics
def load_table(path: Path, expected: list[str]) -> list[dict[str, str]]:
    # The shell stages consume literal, tab-separated fields with read -r.
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")
        return []
    with path.open(encoding="utf-8", newline="") as fh:
        lines = fh.readlines()
    if not lines or lines[0].rstrip("\n").split("\t") != expected:
        fail(f"{path.name}: invalid header")
        return []
    rows = []
    for lineno, line in enumerate(lines[1:], 2):
        fields = line.rstrip("\n").split("\t")
        if (not line.endswith("\n") or len(fields) != len(expected)
                or any(value != value.strip() for value in fields)):
            fail(f"{path.name}:{lineno}: malformed TSV row")
            continue
        rows.append(dict(zip(expected, fields)))
    if not rows:
        fail(f"{path.name}: no data rows")
    return rows


@input_diagnostics
def validate_entrypoints() -> None:
    if not INSTALLER.is_file():
        fail("missing install.sh")
        return

    mode = INSTALLER.stat().st_mode
    if not mode & stat.S_IXUSR:
        fail("install.sh must be executable by its owner (git mode 100755)")


@input_diagnostics
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


@input_diagnostics
def manifest_entries(path: Path, pattern: str, *, required: bool = True) -> list[str]:
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")
        return []
    items = []
    with path.open(encoding="utf-8", newline="") as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.removesuffix("\n")
            if not line or line.startswith("#"):
                continue
            if not raw.endswith("\n") or not re.fullmatch(pattern, line):
                fail(f"{path.name}:{lineno}: invalid manifest entry")
                continue
            items.append(line)
    if required and not items:
        fail(f"{path.name}: empty manifest")
    return items


@input_diagnostics
def validate_stage_inputs() -> None:
    entries = manifest_entries(ROOT / "packages/installer-inputs.txt", r"[A-Za-z0-9_./-]+")
    if len(entries) != len(set(entries)):
        fail("duplicate installer input")
    if REQUIRED_STAGE_INPUTS - set(entries):
        fail("installer-inputs.txt: missing mandatory entries")
    if set(entries) - REQUIRED_STAGE_INPUTS:
        fail("installer-inputs.txt: unreviewed entries")
    for entry in entries:
        path = ROOT / entry
        if (Path(entry).is_absolute() or ".." in Path(entry).parts
                or str(Path(entry)) != entry or not path.resolve().is_relative_to(ROOT)):
            fail(f"invalid repository input path: {entry}")
        elif not path.is_file() or not os.access(path, os.R_OK) or not path.stat().st_size:
            fail(f"missing, empty or unreadable stage input: {entry}")
        elif path.suffix == ".json":
            try:
                json.loads(path.read_text(encoding="utf-8"))
            except (ValueError, OSError):
                fail("invalid or unreadable JSON stage input")
    if not os.access(ROOT / "scripts/generate-dhruva-emoji-pl.py", os.X_OK):
        fail("Dhruva emoji generator must be executable")


validate_stage_inputs()
rpm_pattern = r"[A-Za-z0-9][A-Za-z0-9.+_-]*"
required_rpms = manifest_entries(RPM_REQUIRED, rpm_pattern)
absent_rpms = manifest_entries(RPM_ABSENT, rpm_pattern, required=False)
flatpaks = manifest_entries(ROOT / "packages/flatpak.txt",
                           r"(?:[A-Za-z_][A-Za-z0-9_]*\.){2,}[A-Za-z_][A-Za-z0-9_-]*")
if len(flatpaks) != len(set(flatpaks)):
    fail("duplicate Flatpak application ID")

for package, count in Counter(required_rpms).items():
    if count != 1:
        fail(f"duplicate required RPM: {package} ({count} entries)")

for package, count in Counter(absent_rpms).items():
    if count != 1:
        fail(f"duplicate absent RPM: {package} ({count} entries)")

for package in sorted(set(required_rpms) & set(absent_rpms)):
    fail(f"RPM cannot be both required and absent: {package}")


enabled = manifest_entries(ENABLED, r"[A-Za-z0-9._+-]+@[A-Za-z0-9._+-]+")
rows = load_table(INVENTORY, EXPECTED_HEADER)
lock_rows = load_table(LOCK, EXPECTED_LOCK_HEADER)
tree_lock_rows = load_table(TREE_LOCK, EXPECTED_TREE_LOCK_HEADER)
managed_rows = load_table(MANAGED_SYSTEM, EXPECTED_MANAGED_SYSTEM_HEADER)
validate_weather_locations()
validate_entrypoints()
if not any(row["uuid"] == "ding@rastersoft.com" and row["runtime_version"] == "99"
           and row["shell_major"] == "50" for row in managed_rows):
    fail("managed-system manifest must provide DING v99 for GNOME 50")

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
        if not re.fullmatch(r"https://github\.com/[\w.-]+/[\w.-]+", url):
            fail(
                f"GitHub commit source requires GitHub inventory URL: "
                f"{uuid}: {url!r}"
            )

        if not re.fullmatch(r"[0-9a-f]{64}", sha256):
            fail(
                f"invalid GitHub archive SHA-256 pin: "
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

managed_uuids = [row.get("uuid", "").strip() for row in managed_rows]
for uuid, count in Counter(managed_uuids).items():
    if not uuid:
        fail("managed-system manifest contains an empty UUID")
    elif count != 1:
        fail(f"duplicate managed-system UUID: {uuid} ({count} rows)")

managed_uuid_set = set(managed_uuids)

for row in managed_rows:
    uuid = row.get("uuid", "").strip()
    runtime_version = row.get("runtime_version", "").strip()
    shell_major = row.get("shell_major", "").strip()
    archive_sha256 = row.get("archive_sha256", "").strip()
    managed_tree_sha256 = row.get("managed_tree_sha256", "").strip()
    location = row.get("location", "").strip()

    if not uuid:
        continue

    inventory_row = inventory_by_uuid.get(uuid)
    if inventory_row is None:
        fail(f"managed-system UUID missing from inventory: {uuid}")
        continue

    if uuid not in enabled:
        fail(f"managed-system UUID is not enabled: {uuid}")

    inventory_version = inventory_row.get("version", "").strip()
    inventory_location = inventory_row.get("location", "").strip()

    if runtime_version != inventory_version:
        fail(
            f"managed-system runtime mismatch: {uuid}: "
            f"manifest={runtime_version!r} inventory={inventory_version!r}"
        )

    if not shell_major.isdigit():
        fail(f"invalid managed-system shell major: {uuid}: {shell_major!r}")

    if not re.fullmatch(r"[0-9a-f]{64}", archive_sha256):
        fail(f"invalid managed-system archive SHA-256: {uuid}")

    if not re.fullmatch(r"[0-9a-f]{64}", managed_tree_sha256):
        fail(f"invalid managed-system tree SHA-256: {uuid}")

    expected_location = f"{MANAGED_SYSTEM_PREFIX}{uuid}"
    if location != expected_location:
        fail(
            f"unexpected managed-system manifest location: "
            f"{uuid}: {location!r}"
        )

    if inventory_location != location:
        fail(
            f"managed-system inventory location mismatch: "
            f"{uuid}: manifest={location!r} inventory={inventory_location!r}"
        )

    if uuid in lock_uuid_set:
        fail(f"managed-system extension must not appear in user source lock: {uuid}")

    if uuid in tree_lock_uuid_set:
        fail(f"managed-system extension must not appear in user tree lock: {uuid}")


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

    if location.startswith(MANAGED_SYSTEM_PREFIX) and uuid not in managed_uuid_set:
        fail(
            f"enabled managed-system extension missing managed manifest: {uuid}"
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
    if uuid in enabled and "50" not in shell_versions.split(","):
        fail(f"enabled extension does not support GNOME 50: {uuid}")
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
    elif location.startswith(MANAGED_SYSTEM_PREFIX):
        if not version.isdigit():
            fail(
                f"managed-system extension must have a numeric runtime version pin: "
                f"{uuid}: {version!r}"
            )
        if location != f"{MANAGED_SYSTEM_PREFIX}{uuid}":
            fail(f"unexpected managed-system extension location: {uuid}: {location}")
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
print(f"managed_system_rows={len(managed_rows)}")
print("PASS: enabled extension list and inventory are internally consistent")
print("PASS: extension source locks are internally consistent")
print("PASS: extension tree-integrity locks are complete and internally consistent")
print("PASS: rejected/conflicting extensions are absent from desired state")
print("PASS: user extension pins and portable inventory paths are valid")
print("PASS: managed-system extension pins and locations are internally consistent")
print("PASS: public GNOME Weather location example is structurally valid")
print("PASS: required and absent RPM manifests are internally consistent")
