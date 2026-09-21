#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCANNER = ROOT / "scripts" / "scan-secrets.py"
WORKFLOW = ROOT / ".github" / "workflows" / "static-checks.yml"

spec = importlib.util.spec_from_file_location("secret_scanner", SCANNER)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: unable to load secret scanner")
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


def run_git(repo: Path, *args: str) -> None:
    proc = subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(
            f"FAIL: git {' '.join(args)} failed\n"
            f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        )


with tempfile.TemporaryDirectory(prefix="secret-history-test-") as td:
    repo = Path(td)
    run_git(repo, "init", "-q")
    run_git(repo, "config", "user.name", "Secret Scanner Test")
    run_git(repo, "config", "user.email", "secret-scanner@example.invalid")

    tracked = repo / "fixture.txt"
    tracked.write_text("safe\n", encoding="utf-8")
    run_git(repo, "add", "fixture.txt")
    run_git(repo, "commit", "-q", "-m", "safe baseline")

    synthetic_secret = "ghp_" + ("z" * 28)
    tracked.write_text(synthetic_secret + "\n", encoding="utf-8")
    run_git(repo, "add", "fixture.txt")
    run_git(repo, "commit", "-q", "-m", "historical secret fixture")

    tracked.write_text("safe again\n", encoding="utf-8")
    run_git(repo, "add", "fixture.txt")
    run_git(repo, "commit", "-q", "-m", "remove secret from current tree")

    module.ROOT = repo

    current_findings: list[str] = []
    for path in module.repository_files():
        current_findings.extend(module.scan_path(path))
    if current_findings:
        raise SystemExit(
            "FAIL: current-tree scan should be clean after historical secret removal"
        )

    historical_findings, scanned_blobs = module.scan_history()
    if not any("possible GitHub token" in item for item in historical_findings):
        raise SystemExit(
            "FAIL: full-history scan did not detect a secret removed from current tree"
        )
    if scanned_blobs < 3:
        raise SystemExit("FAIL: history fixture scanned an implausibly small blob set")

workflow = WORKFLOW.read_text(encoding="utf-8")
for phrase in [
    "history-secrets:",
    "fetch-depth: 0",
    "python3 scripts/scan-secrets.py --history",
]:
    if phrase not in workflow:
        raise SystemExit(f"FAIL: history-secret CI contract missing: {phrase}")

print("PASS: current-tree scan ignores a secret removed from the current tree")
print("PASS: full-history scan detects the removed historical secret")
print("PASS: CI checks out complete history and runs the history scanner")
print("=== HISTORY SECRET SCANNER TESTS: PASS ===")
