#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFY = ROOT / "scripts" / "verify-repository-trust.py"
SETUP = ROOT / "scripts" / "setup-repositories.sh"
RPM_MANIFEST = ROOT / "packages" / "rpm.txt"

MOCK_DNF = r'''#!/usr/bin/env python3
import os
import sys

repo = sys.argv[-1]
mode = os.environ.get("REPO_TRUST_TEST_MODE", "valid")

data = {
    "rpmfusion-free": {
        "url_label": "Metalink",
        "url": "https://mirrors.rpmfusion.org/metalink?repo=free-fedora-44&arch=x86_64",
        "key": "file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-44",
    },
    "rpmfusion-nonfree": {
        "url_label": "Metalink",
        "url": "https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-44&arch=x86_64",
        "key": "file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-44",
    },
    "brave-browser": {
        "url_label": "Base URL",
        "url": "https://brave-browser-rpm-release.s3.brave.com/x86_64",
        "key": "file:///usr/share/distribution-gpg-keys/brave/brave-core.asc",
    },
    "copr:copr.fedorainfracloud.org:imput:helium": {
        "url_label": "Base URL",
        "url": "https://download.copr.fedorainfracloud.org/results/imput/helium/fedora-44-x86_64/",
        "key": "file:///usr/share/distribution-gpg-keys/copr/copr-imput-helium.gpg",
        "include": "helium-bin",
    },
    "copr:copr.fedorainfracloud.org:tgerov:vpcs": {
        "url_label": "Base URL",
        "url": "https://download.copr.fedorainfracloud.org/results/tgerov/vpcs/fedora-44-x86_64/",
        "key": "file:///usr/share/distribution-gpg-keys/copr/copr-tgerov-vpcs.gpg",
        "include": "vpcs",
    },
}

if repo not in data:
    raise SystemExit(2)

item = data[repo]
if mode == "brave-url-drift" and repo == "brave-browser":
    item["url"] = "https://example.invalid/brave/x86_64"
if mode == "brave-key-uri-drift" and repo == "brave-browser":
    item["key"] = "https://brave-browser-rpm-release.s3.brave.com/brave-core.asc"
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

MOCK_RPMKEYS = r'''#!/usr/bin/env python3
import os

mode = os.environ.get("REPO_TRUST_TEST_MODE", "valid")
fingerprints = [
    ("E9A491A3DE247814E7E067EAE06F8ECDD651FF2E", "RPM Fusion free"),
    ("79BDB88F9BBF73910FD4095B6A2AF96194843C65", "RPM Fusion nonfree"),
    ("DBF1A116C220B8C7164F98230686B78420038257", "Brave Linux Release"),
    ("07BCFCA30AC7E51BCFEDFFF74A3186EA47912C39", "imput_helium"),
    ("95EB28345BC0F53E9762B27FD865F5EFB8050E1C", "tgerov_vpcs"),
]
for fingerprint, label in fingerprints:
    if mode == "missing-helium-fingerprint" and label == "imput_helium":
        continue
    print(f"{fingerprint.lower()} {label} public key")
'''

MOCK_RPM = r'''#!/usr/bin/env python3
import os
import sys

mode = os.environ.get("REPO_TRUST_TEST_MODE", "valid")
args = sys.argv[1:]

owners = {
    "/usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-44":
        "distribution-gpg-keys",
    "/usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-44":
        "distribution-gpg-keys",
    "/usr/share/distribution-gpg-keys/brave/brave-core.asc":
        "distribution-gpg-keys",
    "/usr/share/distribution-gpg-keys/copr/copr-imput-helium.gpg":
        "distribution-gpg-keys-copr",
    "/usr/share/distribution-gpg-keys/copr/copr-tgerov-vpcs.gpg":
        "distribution-gpg-keys-copr",
}

signers = {
    "rpmfusion-free-release": "E06F8ECDD651FF2E",
    "rpmfusion-nonfree-release": "6A2AF96194843C65",
    "brave-origin": "0686B78420038257",
    "helium-bin": "4A3186EA47912C39",
    "vpcs": "D865F5EFB8050E1C",
}

if len(args) >= 2 and args[0] == "-V":
    package = args[1]
    if mode == "tampered-trust-package" and package == "distribution-gpg-keys-copr":
        print("S.5....T.  /usr/share/distribution-gpg-keys/copr/copr-imput-helium.gpg")
        raise SystemExit(1)
    raise SystemExit(0)

if args[:1] == ["-q"] and len(args) == 2:
    package = args[1]
    if package in {"distribution-gpg-keys", "distribution-gpg-keys-copr"}:
        print(package)
        raise SystemExit(0)

if args[:2] == ["-qf", "--qf"]:
    path = args[-1]
    owner = owners.get(path)
    if mode == "wrong-key-owner" and path.endswith("brave-core.asc"):
        owner = "evil-key-package"
    if owner is None:
        raise SystemExit(1)
    print(owner)
    raise SystemExit(0)

if args[:1] == ["-q"] and "--qf" in args:
    package = args[1]
    key_id = signers.get(package)
    if mode == "wrong-vpcs-signer" and package == "vpcs":
        key_id = "0123456789ABCDEF"
    if key_id is None:
        raise SystemExit(1)
    print(f"RSA/SHA256, test timestamp, Key ID {key_id}")
    raise SystemExit(0)

raise SystemExit(2)
'''


def run_case(mode: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory() as tmp:
        bindir = Path(tmp)
        for name, content in {
            "dnf": MOCK_DNF,
            "rpmkeys": MOCK_RPMKEYS,
            "rpm": MOCK_RPM,
        }.items():
            path = bindir / name
            path.write_text(content, encoding="utf-8")
            path.chmod(0o755)

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


expect_pass("valid reviewed repository provenance", run_case("valid"))
expect_fail(
    "Brave source drift",
    run_case("brave-url-drift"),
    "Base URL outside reviewed source",
)
expect_fail(
    "Brave remote key URI replaces Fedora-distributed trust anchor",
    run_case("brave-key-uri-drift"),
    "OpenPGP key URI must be pinned",
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
expect_fail(
    "Helium reviewed fingerprint missing",
    run_case("missing-helium-fingerprint"),
    "reviewed OpenPGP fingerprint is not imported",
)
expect_fail(
    "VPCS package signer drift",
    run_case("wrong-vpcs-signer"),
    "package signer drift",
)
expect_fail(
    "Fedora trust-anchor package tampering",
    run_case("tampered-trust-package"),
    "installed trust-anchor files failed rpm -V",
)
expect_fail(
    "Brave key file owned by unexpected package",
    run_case("wrong-key-owner"),
    "pinned OpenPGP key must exist and be owned by distribution-gpg-keys",
)


rpm_manifest = {
    line.strip()
    for line in RPM_MANIFEST.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
}
for package in {"dnf-plugins-core", "distribution-gpg-keys", "distribution-gpg-keys-copr"}:
    if package not in rpm_manifest:
        raise SystemExit(f"FAIL: required repository-trust RPM missing from manifest: {package}")

setup_text = SETUP.read_text(encoding="utf-8")
required_setup_contract = (
    "distribution-gpg-keys distribution-gpg-keys-copr",
    'sudo rpm --import "$RPMFUSION_FREE_KEY" "$RPMFUSION_NONFREE_KEY"',
    '"rpmfusion-free.gpgkey=file://${RPMFUSION_FREE_KEY}"',
    '"rpmfusion-nonfree.gpgkey=file://${RPMFUSION_NONFREE_KEY}"',
    '"brave-browser.gpgkey=file://${BRAVE_KEY}"',
    '"${HELIUM_REPO_ID}.gpgkey=file://${HELIUM_KEY}"',
    '"${VPCS_REPO_ID}.gpgkey=file://${VPCS_KEY}"',
    '"${HELIUM_REPO_ID}.includepkgs=helium-bin"',
    '"${VPCS_REPO_ID}.includepkgs=vpcs"',
)
for needle in required_setup_contract:
    if needle not in setup_text:
        raise SystemExit(f"FAIL: setup-repositories provenance contract missing: {needle}")

print("PASS: external repository provenance/trust fixtures")
