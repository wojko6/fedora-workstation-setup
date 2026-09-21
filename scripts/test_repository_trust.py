#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFY = ROOT / "scripts" / "verify-repository-trust.py"


MOCK_DNF = r'''#!/usr/bin/env python3
import os
import sys

repo = sys.argv[-1]
mode = os.environ.get("REPO_TRUST_TEST_MODE", "valid")

data = {
    "rpmfusion-free": {
        "url_label": "Metalink",
        "url": "https://mirrors.rpmfusion.org/metalink?repo=free-fedora-44&arch=x86_64",
        "key": "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-44",
    },
    "rpmfusion-nonfree": {
        "url_label": "Metalink",
        "url": "https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-44&arch=x86_64",
        "key": "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-44",
    },
    "brave-browser": {
        "url_label": "Base URL",
        "url": "https://brave-browser-rpm-release.s3.brave.com/x86_64",
        "key": "https://brave-browser-rpm-release.s3.brave.com/brave-core.asc",
    },
    "copr:copr.fedorainfracloud.org:imput:helium": {
        "url_label": "Base URL",
        "url": "https://download.copr.fedorainfracloud.org/results/imput/helium/fedora-44-x86_64/",
        "key": "https://download.copr.fedorainfracloud.org/results/imput/helium/pubkey.gpg",
        "include": "helium-bin",
    },
    "copr:copr.fedorainfracloud.org:tgerov:vpcs": {
        "url_label": "Base URL",
        "url": "https://download.copr.fedorainfracloud.org/results/tgerov/vpcs/fedora-44-x86_64/",
        "key": "https://download.copr.fedorainfracloud.org/results/tgerov/vpcs/pubkey.gpg",
        "include": "vpcs",
    },
}

if repo not in data:
    raise SystemExit(2)

item = data[repo]
if mode == "brave-url-drift" and repo == "brave-browser":
    item["url"] = "https://example.invalid/brave/x86_64"
if mode == "unsigned-vpcs" and repo.endswith(":tgerov:vpcs"):
    verify = "false"
else:
    verify = "true"
if mode == "helium-unscoped" and repo.endswith(":imput:helium"):
    item["include"] = ""

print(f"Repo ID              : {repo}")
print("Status               : enabled")
if item.get("include"):
    print(f"Include packages     : {item['include']}")
print("URLs                 :")
print(f"  {item['url_label']}           : {item['url']}")
print("OpenPGP              :")
print(f"  Keys               : {item['key']}")
print(f"  Verify packages    : {verify}")
'''


def run_case(mode: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory() as tmp:
        bindir = Path(tmp)
        dnf = bindir / "dnf"
        dnf.write_text(MOCK_DNF, encoding="utf-8")
        dnf.chmod(0o755)
        env = os.environ.copy()
        env["PATH"] = f"{bindir}:{env['PATH']}"
        env["REPO_TRUST_TEST_MODE"] = mode
        return subprocess.run(
            [sys.executable, str(VERIFY)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=env,
            check=False,
        )


def expect_pass(name: str, result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode != 0:
        raise SystemExit(f"FAIL: {name}\n{result.stdout}")


def expect_fail(name: str, result: subprocess.CompletedProcess[str], needle: str) -> None:
    if result.returncode == 0 or needle not in result.stdout:
        raise SystemExit(f"FAIL: {name}\n{result.stdout}")


expect_pass("valid reviewed repository policy", run_case("valid"))
expect_fail(
    "Brave source drift",
    run_case("brave-url-drift"),
    "Base URL outside reviewed source",
)
expect_fail(
    "VPCS package signature verification disabled",
    run_case("unsigned-vpcs"),
    "package signature verification is not enabled",
)
expect_fail(
    "Helium COPR left unscoped",
    run_case("helium-unscoped"),
    "Include packages must be helium-bin",
)

print("PASS: external repository trust fixtures")
