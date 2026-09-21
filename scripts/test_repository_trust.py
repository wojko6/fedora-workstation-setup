#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERIFY = ROOT / "scripts" / "verify-repository-trust.py"
SETUP = ROOT / "scripts" / "setup-repositories.sh"
RPM_MANIFEST = ROOT / "packages" / "rpm.txt"

spec = importlib.util.spec_from_file_location("repository_trust_verify", VERIFY)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: unable to load repository trust verifier")
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

TRUST_PACKAGES, POLICIES = module.load_policy()

FPRS = {
    "rpmfusion-free": ["E9A491A3DE247814E7E067EAE06F8ECDD651FF2E"],
    "rpmfusion-nonfree": ["79BDB88F9BBF73910FD4095B6A2AF96194843C65"],
    "brave-browser": [
        "DBF1A116C220B8C7164F98230686B78420038257",
        "47D32A74E9A9E013A4B4926C68D513D36A73CD96",
        "B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0",
    ],
    "copr:copr.fedorainfracloud.org:imput:helium": [
        "07BCFCA30AC7E51BCFEDFFF74A3186EA47912C39"
    ],
    "copr:copr.fedorainfracloud.org:tgerov:vpcs": [
        "95EB28345BC0F53E9762B27FD865F5EFB8050E1C"
    ],
}

KEY_IDS = {
    "rpmfusion-free-release": "E06F8ECDD651FF2E",
    "rpmfusion-nonfree-release": "6A2AF96194843C65",
    "brave-origin": "0686B78420038257",
    "helium-bin": "4A3186EA47912C39",
    "vpcs": "D865F5EFB8050E1C",
}


def completed(args: list[str], stdout: str = "", stderr: str = "", rc: int = 0):
    return subprocess.CompletedProcess(args, rc, stdout, stderr)


def repo_from_key_path(path: str) -> str:
    if "rpmfusion-free-fedora-44" in path:
        return "rpmfusion-free"
    if "rpmfusion-nonfree-fedora-44" in path:
        return "rpmfusion-nonfree"
    if "brave-core-reviewed.asc" in path:
        return "brave-browser"
    if "copr-imput-helium.gpg" in path:
        return "copr:copr.fedorainfracloud.org:imput:helium"
    if "copr-tgerov-vpcs.gpg" in path:
        return "copr:copr.fedorainfracloud.org:tgerov:vpcs"
    raise AssertionError(f"unexpected key path: {path}")


def fake_run_factory(mode: str):
    def fake_run(command: list[str]):
        if command[:3] == ["dnf", "repo", "info"]:
            repo = command[3]
            policy = module.policy_by_id(repo, POLICIES)
            url = policy.url_prefix + "44&arch=x86_64"
            key_uri = policy.key_uri
            include = policy.include_packages
            verify_packages = "true"

            if mode == "brave-url-drift" and repo == "brave-browser":
                url = "https://example.invalid/brave/x86_64"
            if mode == "brave-key-uri-drift" and repo == "brave-browser":
                key_uri = "file:///usr/share/distribution-gpg-keys/brave/brave-core.asc"
            if mode == "unsigned-vpcs" and repo.endswith(":tgerov:vpcs"):
                verify_packages = "false"
            if mode == "helium-unscoped" and repo.endswith(":imput:helium"):
                include = None

            lines = [f"Repo ID              : {repo}", "Status               : enabled"]
            if include:
                lines.append(f"Include packages     : {include}")
            lines.extend(
                [
                    f"  {policy.url_field}           : {url}",
                    f"  Keys               : {key_uri}",
                    f"  Verify packages    : {verify_packages}",
                ]
            )
            return completed(command, "\n".join(lines) + "\n")

        if command[:4] == ["gpg", "--batch", "--with-colons", "--show-keys"]:
            repo = repo_from_key_path(command[4])
            fingerprints = list(FPRS[repo])
            if mode == "helium-fingerprint-drift" and repo.endswith(":imput:helium"):
                fingerprints = ["1111111111111111111111111111111111111111"]
            if mode == "brave-historical-key" and repo == "brave-browser":
                fingerprints = ["D8BAD4DE7EE17AF52A834B2D0BB75829C2D4E821"]

            lines: list[str] = []
            for fpr in fingerprints:
                lines.append(
                    "pub:-:4096:1:0000000000000000:0:0::::::scESC::::::23::0:"
                )
                lines.append(f"fpr:::::::::{fpr}:")
                lines.append("uid:-::::0::0::::::::Mock key:")
            return completed(command, "\n".join(lines) + "\n")

        if command == ["rpmkeys", "--list"]:
            fingerprints = [fpr for values in FPRS.values() for fpr in values]
            if mode == "missing-vpcs-imported-key":
                fingerprints.remove("95EB28345BC0F53E9762B27FD865F5EFB8050E1C")
            return completed(
                command,
                "".join(f"{fpr.lower()} Mock public key\n" for fpr in fingerprints),
            )

        if command[:2] == ["rpm", "-V"]:
            package = command[2]
            if mode == "tampered-trust-package" and package == "distribution-gpg-keys-copr":
                return completed(
                    command,
                    "S.5....T.  /usr/share/distribution-gpg-keys/copr/copr-imput-helium.gpg\n",
                    rc=1,
                )
            return completed(command)

        if command[:2] == ["rpm", "-q"] and len(command) == 3:
            package = command[2]
            if package in TRUST_PACKAGES:
                return completed(command, package + "\n")

        if command[:3] == ["rpm", "-qf", "--qf"]:
            path = command[4]
            repo = repo_from_key_path(path)
            policy = module.policy_by_id(repo, POLICIES)
            owner = policy.key_owner
            if mode == "wrong-key-owner" and repo.endswith(":imput:helium"):
                owner = "evil-key-package"
            if owner is None:
                return completed(command, rc=1)
            return completed(command, owner + "\n")

        if command[:2] == ["rpm", "-q"] and "--qf" in command:
            package = command[2]
            key_id = KEY_IDS[package]
            if mode == "brave-signer-drift" and package == "brave-origin":
                key_id = "AAAAAAAAAAAAAAAA"
            return completed(
                command,
                f"{package}-1-1.x86_64\nRSA/SHA256, test, Key ID {key_id}\n",
            )

        raise AssertionError(f"unexpected command: {command}")

    return fake_run


def run_case(mode: str) -> list[str]:
    module.run = fake_run_factory(mode)
    errors = module.verify_trust_packages(TRUST_PACKAGES)
    imported = module.imported_fingerprints()
    for policy in POLICIES:
        errors.extend(module.check_policy(policy, imported))
    return errors


def expect_pass(name: str, errors: list[str]) -> None:
    if errors:
        raise SystemExit(f"FAIL: {name}\n" + "\n".join(errors))


def expect_fail(name: str, errors: list[str], needle: str) -> None:
    if not errors or not any(needle in error for error in errors):
        raise SystemExit(f"FAIL: {name}\n" + "\n".join(errors))


expect_pass("valid pinned repository trust", run_case("valid"))
expect_fail(
    "Brave source drift",
    run_case("brave-url-drift"),
    "Base URL outside reviewed source",
)
expect_fail(
    "Brave historical Fedora key path restored",
    run_case("brave-key-uri-drift"),
    "OpenPGP key URI must be file:///etc/pki/rpm-gpg/brave-core-reviewed.asc",
)
expect_fail(
    "Brave historical key material",
    run_case("brave-historical-key"),
    "trust-anchor fingerprint mismatch",
)
expect_fail(
    "VPCS signature verification disabled",
    run_case("unsigned-vpcs"),
    "package signature verification is not enabled",
)
expect_fail(
    "Helium COPR left unscoped",
    run_case("helium-unscoped"),
    "Include packages must be helium-bin",
)
expect_fail(
    "Helium trust-anchor fingerprint drift",
    run_case("helium-fingerprint-drift"),
    "trust-anchor fingerprint mismatch",
)
expect_fail(
    "VPCS reviewed key missing from RPM keyring",
    run_case("missing-vpcs-imported-key"),
    "reviewed OpenPGP fingerprint(s) not imported into RPM keyring",
)
expect_fail(
    "Brave package signer drift",
    run_case("brave-signer-drift"),
    "signed by unexpected key id(s)",
)
expect_fail(
    "Fedora trust-anchor package tampering",
    run_case("tampered-trust-package"),
    "installed trust-anchor files failed rpm -V",
)
expect_fail(
    "COPR key owned by unexpected package",
    run_case("wrong-key-owner"),
    "trust-anchor file must be owned by distribution-gpg-keys-copr",
)

rpm_manifest = {
    line.strip()
    for line in RPM_MANIFEST.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
}
for package in {
    "dnf-plugins-core",
    "distribution-gpg-keys",
    "distribution-gpg-keys-copr",
    "gnupg2",
}:
    if package not in rpm_manifest:
        raise SystemExit(f"FAIL: required repository-trust RPM missing from manifest: {package}")

setup_text = SETUP.read_text(encoding="utf-8")
for needle in (
    'python3 "$TRUST_VERIFY" --check-key brave-browser',
    'BRAVE_KEY="/etc/pki/rpm-gpg/brave-core-reviewed.asc"',
    '"brave-browser.gpgkey=file://${BRAVE_KEY}"',
    '"${HELIUM_REPO_ID}.includepkgs=helium-bin"',
    '"${VPCS_REPO_ID}.includepkgs=vpcs"',
):
    if needle not in setup_text:
        raise SystemExit(f"FAIL: setup-repositories trust contract missing: {needle}")

print("PASS: external repository provenance/trust fixtures")
