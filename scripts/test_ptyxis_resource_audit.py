#!/usr/bin/env python3
"""Static fixtures for Ptyxis UI-resource localization auditing."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "ptyxis_resource_audit.py"

spec = importlib.util.spec_from_file_location("ptyxis_resource_audit", MODULE_PATH)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: unable to load Ptyxis resource audit helper")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

xml = b"""<interface>
<object>
  <property name="title" translatable="yes">Behavior</property>
  <property name="subtitle" translatable="yes">Terminal</property>
  <property name="label" translatable="yes" context="button">Set</property>
  <property name="duplicate" translatable="yes">Behavior</property>
</object>
</interface>"""

pairs = list(module.iter_translatable(xml))
assert pairs == [
    ("", "Behavior"),
    ("", "Terminal"),
    ("button", "Set"),
], pairs

good_catalog = {
    "Behavior": "Zachowanie",
    "Terminal": "Terminal",
    "button\x04Set": "Ustaw",
}
assert module.audit_pairs(pairs, good_catalog) == []

missing = module.audit_pairs(pairs, {"Behavior": "Zachowanie"})
assert len(missing) == 2
assert any(item[1] == "Terminal" and item[2] == "missing catalog entry" for item in missing)
assert any(item[1] == "Set" and item[2] == "missing catalog entry" for item in missing)

english = module.audit_pairs(
    pairs,
    {
        "Behavior": "Behavior",
        "Terminal": "Terminal",
        "button\x04Set": "Set",
    },
)
assert len(english) == 2
assert {item[1] for item in english} == {"Behavior", "Set"}

empty = module.audit_pairs(
    pairs,
    {
        "Behavior": "",
        "Terminal": "Terminal",
        "button\x04Set": "Ustaw",
    },
)
assert empty == [("", "Behavior", "empty catalog translation")]

print("PASS: Ptyxis resource-audit fixtures")
