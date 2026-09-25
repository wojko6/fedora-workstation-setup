#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / "patches" / "gnome-extensions" / "ding" / "desktopMenu-system-monitor.patch"
INSTALL = ROOT / "scripts" / "install-ding-system-monitor-menu.sh"
VERIFY = ROOT / "scripts" / "verify-ding-system-monitor-menu.sh"
MAIN_INSTALL = ROOT / "install.sh"
MAIN_VERIFY = ROOT / "scripts" / "verify.sh"
DING_PO = ROOT / "localization" / "ding" / "pl.po"

FIXTURE = """class DesktopMenuFixture {
    constructor() {
        this._addNewAction('show-in-files', null, () => this._onOpenDesktopInFilesClicked());
        this._addNewAction('open-in-terminal-desktop', null, () => {
            DesktopIconsUtil.launchTerminal(this._desktopDir.get_path(), null);
        });
        this._addNewAction('change-background', null, () => {
            const desktopFile = GioUnix.DesktopAppInfo.new('gnome-background-panel.desktop');
            const context = Gdk.Display.get_default().get_app_launch_context();
            context.set_timestamp(Gdk.CURRENT_TIME);
            desktopFile.launch([], context);
        });
    }

    async _createDesktopBackgroundMenu() {
        let menuContainer = new Gio.Menu();
        let section = this._newSection(menuContainer);

        section = this._newSection(menuContainer);
        this._newMenuElement(_('Show Desktop in Files'), "show-in-files", section);
        this._newMenuElement(_('Open in Terminal'), "open-in-terminal-desktop", section);

        section = this._newSection(menuContainer);
        this._newMenuElement(_('Change Background…'), "change-background", section);

        return menuContainer;
    }
}
"""

if not PATCH.is_file():
    raise SystemExit("FAIL: DING System Monitor patch missing")

with tempfile.TemporaryDirectory(prefix="ding-system-monitor-") as td:
    root = Path(td)
    app = root / "app"
    app.mkdir()
    target = app / "desktopMenu.js"
    target.write_text(FIXTURE, encoding="utf-8")

    check = subprocess.run(
        ["patch", "--dry-run", "--batch", "--forward", "-p1", "-d", str(root)],
        input=PATCH.read_text(encoding="utf-8"),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check.returncode != 0:
        raise SystemExit(
            "FAIL: DING System Monitor patch does not apply to audited fixture\n"
            f"stdout:\n{check.stdout}\nstderr:\n{check.stderr}"
        )

    apply = subprocess.run(
        ["patch", "--batch", "--forward", "-p1", "-d", str(root)],
        input=PATCH.read_text(encoding="utf-8"),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if apply.returncode != 0:
        raise SystemExit(
            "FAIL: DING System Monitor fixture patch failed\n"
            f"stdout:\n{apply.stdout}\nstderr:\n{apply.stderr}"
        )

    text = target.read_text(encoding="utf-8")
    required = [
        "this._addNewAction('open-system-monitor', null, () => {",
        "GioUnix.DesktopAppInfo.new('org.gnome.SystemMonitor.desktop')",
        'this._newMenuElement(_(\'System Monitor\'), "open-system-monitor", section);',
    ]
    for phrase in required:
        if text.count(phrase) != 1:
            raise SystemExit(
                f"FAIL: patched DING fixture missing or duplicates: {phrase}"
            )

print("PASS: DING System Monitor patch applies to audited source fixture")

contracts = {
    INSTALL: [
        "desktopMenu-system-monitor.patch",
        "org.gnome.SystemMonitor.desktop",
        "EXPECTED_VERSION=\"97\"",
        "patch --dry-run",
        "verify-ding-system-monitor-menu.sh",
    ],
    VERIFY: [
        "org.gnome.SystemMonitor.desktop",
        "open-system-monitor",
        "System Monitor",
        "Monitor systemu",
        "EXPECTED_VERSION=\"97\"",
    ],
    MAIN_INSTALL: [
        "scripts/install-ding-system-monitor-menu.sh",
    ],
    MAIN_VERIFY: [
        "=== DING SYSTEM MONITOR MENU ===",
        "verify-ding-system-monitor-menu.sh",
    ],
}

for path, phrases in contracts.items():
    text = path.read_text(encoding="utf-8")
    for phrase in phrases:
        if phrase not in text:
            raise SystemExit(
                f"FAIL: DING System Monitor integration contract missing in {path.name}: {phrase}"
            )

po_text = DING_PO.read_text(encoding="utf-8")
if 'msgid "System Monitor"\nmsgstr "Monitor systemu"' not in po_text:
    raise SystemExit("FAIL: DING Polish catalog is missing System Monitor -> Monitor systemu")

print("PASS: DING System Monitor restore and verification contracts present")
print("PASS: DING System Monitor label is gettext-managed in the Polish catalog")
print("=== DING SYSTEM MONITOR TESTS: PASS ===")
