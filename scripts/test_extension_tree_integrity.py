#!/usr/bin/env python3
from __future__ import annotations

import os
import stat
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "scripts" / "extension_tree_integrity.py"


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["python3", str(TOOL), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        raise SystemExit(
            f"FAIL: {' '.join(args)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def tree_hash(path: Path) -> str:
    return run("hash", "--path", str(path)).stdout.strip()


with tempfile.TemporaryDirectory(prefix="extension-tree-integrity-") as td:
    base = Path(td)
    tree = base / "tree"
    tree.mkdir()
    (tree / "metadata.json").write_text(
        '{"uuid":"fixture@example","version":1}\n',
        encoding="utf-8",
    )
    (tree / "extension.js").write_text(
        "export default class Fixture {}\n",
        encoding="utf-8",
    )
    nested = tree / "schemas"
    nested.mkdir()
    schema = nested / "org.example.gschema.xml"
    schema.write_text("<schemalist/>\n", encoding="utf-8")

    first = tree_hash(tree)
    second = tree_hash(tree)
    if first != second:
        raise SystemExit("FAIL: identical tree hash is not deterministic")
    print("PASS: identical extension tree hashes deterministically")

    (tree / "extension.js").write_text(
        "export default class Tampered {}\n",
        encoding="utf-8",
    )
    changed_content = tree_hash(tree)
    if changed_content == first:
        raise SystemExit("FAIL: file-content tamper did not change tree hash")
    print("PASS: file-content tamper changes tree hash")

    (tree / "extension.js").write_text(
        "export default class Fixture {}\n",
        encoding="utf-8",
    )
    extra = tree / "unexpected.js"
    extra.write_text("unexpected\n", encoding="utf-8")
    changed_extra = tree_hash(tree)
    if changed_extra == first:
        raise SystemExit("FAIL: added file did not change tree hash")
    extra.unlink()
    print("PASS: added file changes tree hash")

    mode_before = tree_hash(tree)
    current_mode = stat.S_IMODE((tree / "extension.js").stat().st_mode)
    os.chmod(tree / "extension.js", current_mode ^ stat.S_IXUSR)
    mode_after = tree_hash(tree)
    if mode_after == mode_before:
        raise SystemExit("FAIL: regular-file mode change did not change tree hash")
    os.chmod(tree / "extension.js", current_mode)
    print("PASS: regular-file mode change changes tree hash")

    target_a = tree / "target-a"
    target_b = tree / "target-b"
    target_a.write_text("a\n", encoding="utf-8")
    target_b.write_text("b\n", encoding="utf-8")
    link = tree / "link"
    link.symlink_to("target-a")
    symlink_a = tree_hash(tree)
    link.unlink()
    link.symlink_to("target-b")
    symlink_b = tree_hash(tree)
    if symlink_a == symlink_b:
        raise SystemExit("FAIL: symlink target change did not change tree hash")
    print("PASS: symlink target change changes tree hash")

    inventory = base / "inventory.tsv"
    enabled = base / "enabled.txt"
    extensions_root = base / "extensions"
    extension = extensions_root / "fixture@example"
    extension.mkdir(parents=True)
    (extension / "metadata.json").write_text(
        '{"uuid":"fixture@example","version":1}\n',
        encoding="utf-8",
    )
    (extension / "extension.js").write_text("fixture\n", encoding="utf-8")

    inventory.write_text(
        "uuid\tname\tversion\tshell_versions\turl\tlocation\n"
        "fixture@example\tFixture\t1\t50\thttps://example.invalid\t"
        "~/.local/share/gnome-shell/extensions/fixture@example\n",
        encoding="utf-8",
    )
    enabled.write_text("fixture@example\n", encoding="utf-8")

    generated = run(
        "generate",
        "--inventory",
        str(inventory),
        "--enabled",
        str(enabled),
        "--extensions-root",
        str(extensions_root),
    ).stdout

    lock = base / "tree-lock.tsv"
    lock.write_text(generated, encoding="utf-8")

    verify = run(
        "verify",
        "--lock",
        str(lock),
        "--inventory",
        str(inventory),
        "--enabled",
        str(enabled),
        "--extensions-root",
        str(extensions_root),
    )
    if "PASS: extension tree integrity fixture@example" not in verify.stdout:
        raise SystemExit("FAIL: generated lock did not verify accepted tree")
    print("PASS: generated tree lock verifies accepted tree")

    (extension / "extension.js").write_text("tampered\n", encoding="utf-8")
    verify = run(
        "verify",
        "--lock",
        str(lock),
        "--inventory",
        str(inventory),
        "--enabled",
        str(enabled),
        "--extensions-root",
        str(extensions_root),
        check=False,
    )
    if verify.returncode == 0:
        raise SystemExit("FAIL: tampered tree unexpectedly verified")
    if "FAIL: extension tree integrity drift: fixture@example" not in verify.stdout:
        raise SystemExit("FAIL: tampered tree failure reason missing")
    print("PASS: tree lock rejects same-version content tamper")

print("=== EXTENSION TREE INTEGRITY TESTS: PASS ===")
