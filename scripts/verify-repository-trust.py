#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class RepoPolicy:
    repo_id: str
    url_field: str
    url_prefix: str
    key_uri: str
    key_fingerprint: str
    key_owner: str
    package: str
    include_packages: str | None = None


POLICIES = (
    RepoPolicy(
        "rpmfusion-free",
        "Metalink",
        "https://mirrors.rpmfusion.org/metalink?repo=free-fedora-",
        "file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-44",
        "E9A491A3DE247814E7E067EAE06F8ECDD651FF2E",
        "distribution-gpg-keys",
        "rpmfusion-free-release",
    ),
    RepoPolicy(
        "rpmfusion-nonfree",
        "Metalink",
        "https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-",
        "file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-44",
        "79BDB88F9BBF73910FD4095B6A2AF96194843C65",
        "distribution-gpg-keys",
        "rpmfusion-nonfree-release",
    ),
    RepoPolicy(
        "brave-browser",
        "Base URL",
        "https://brave-browser-rpm-release.s3.brave.com/",
        "file:///usr/share/distribution-gpg-keys/brave/brave-core.asc",
        "DBF1A116C220B8C7164F98230686B78420038257",
        "distribution-gpg-keys",
        "brave-origin",
    ),
    RepoPolicy(
        "copr:copr.fedorainfracloud.org:imput:helium",
        "Base URL",
        "https://download.copr.fedorainfracloud.org/results/imput/helium/",
        "file:///usr/share/distribution-gpg-keys/copr/copr-imput-helium.gpg",
        "07BCFCA30AC7E51BCFEDFFF74A3186EA47912C39",
        "distribution-gpg-keys-copr",
        "helium-bin",
        "helium-bin",
    ),
    RepoPolicy(
        "copr:copr.fedorainfracloud.org:tgerov:vpcs",
        "Base URL",
        "https://download.copr.fedorainfracloud.org/results/tgerov/vpcs/",
        "file:///usr/share/distribution-gpg-keys/copr/copr-tgerov-vpcs.gpg",
        "95EB28345BC0F53E9762B27FD865F5EFB8050E1C",
        "distribution-gpg-keys-copr",
        "vpcs",
        "vpcs",
    ),
)

KEY_PACKAGES = ("distribution-gpg-keys", "distribution-gpg-keys-copr")
FINGERPRINT_RE = re.compile(r"^([0-9A-Fa-f]{40})\s+")
SIGNER_RE = re.compile(r"Key ID ([0-9A-Fa-f]{16,40})")


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "LC_ALL": "C"},
        check=False,
    )


def repo_info(repo_id: str) -> dict[str, str]:
    proc = run(["dnf", "repo", "info", repo_id])
    if proc.returncode != 0:
        raise RuntimeError(
            f"dnf repo info failed for {repo_id}: "
            f"{proc.stderr.strip() or 'no diagnostic'}"
        )

    fields: dict[str, str] = {}
    for raw in proc.stdout.splitlines():
        if ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in {
            "Repo ID",
            "Status",
            "Include packages",
            "Base URL",
            "Metalink",
            "Keys",
            "Verify packages",
        }:
            fields[key] = value
    return fields


def imported_key_fingerprints() -> set[str]:
    proc = run(["rpmkeys", "--list"])
    if proc.returncode != 0:
        raise RuntimeError(
            f"rpmkeys --list failed: {proc.stderr.strip() or 'no diagnostic'}"
        )

    fingerprints: set[str] = set()
    for line in proc.stdout.splitlines():
        match = FINGERPRINT_RE.match(line.strip())
        if match:
            fingerprints.add(match.group(1).upper())
    return fingerprints


def verify_key_packages() -> list[str]:
    errors: list[str] = []
    for package in KEY_PACKAGES:
        installed = run(["rpm", "-q", package])
        if installed.returncode != 0:
            errors.append(f"required Fedora trust-anchor package missing: {package}")
            continue

        verified = run(["rpm", "-V", package])
        if verified.returncode != 0 or verified.stdout.strip():
            detail = verified.stdout.strip() or verified.stderr.strip() or "verification failed"
            errors.append(f"{package}: installed trust-anchor files failed rpm -V: {detail}")
    return errors


def key_path_from_uri(uri: str) -> str:
    prefix = "file://"
    if not uri.startswith(prefix):
        raise ValueError(f"not a local file URI: {uri}")
    return uri[len(prefix):]


def key_owner(path: str) -> str | None:
    proc = run(["rpm", "-qf", "--qf", "%{NAME}\n", path])
    if proc.returncode != 0:
        return None
    owners = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    return owners[0] if len(owners) == 1 else None


def package_signer_key_ids(package: str) -> set[str]:
    proc = run(["rpm", "-q", package, "--qf", "[%{OPENPGP:pgpsig}\n]"])
    if proc.returncode != 0:
        raise RuntimeError(
            f"required package missing or signature query failed for {package}: "
            f"{proc.stderr.strip() or 'no diagnostic'}"
        )

    key_ids = {match.group(1).upper() for match in SIGNER_RE.finditer(proc.stdout)}
    if not key_ids:
        raise RuntimeError(f"{package}: no OpenPGP package signer key ID found")
    return key_ids


def check_policy(policy: RepoPolicy, imported: set[str]) -> list[str]:
    errors: list[str] = []
    try:
        fields = repo_info(policy.repo_id)
    except RuntimeError as exc:
        return [str(exc)]

    if fields.get("Repo ID") != policy.repo_id:
        errors.append(
            f"{policy.repo_id}: effective Repo ID mismatch: "
            f"{fields.get('Repo ID', 'missing')}"
        )

    if fields.get("Status") != "enabled":
        errors.append(
            f"{policy.repo_id}: repository is not enabled: "
            f"{fields.get('Status', 'missing')}"
        )

    url = fields.get(policy.url_field, "")
    if not url.startswith(policy.url_prefix):
        errors.append(
            f"{policy.repo_id}: {policy.url_field} outside reviewed source: "
            f"{url or 'missing'}"
        )

    key = fields.get("Keys", "")
    if key != policy.key_uri:
        errors.append(
            f"{policy.repo_id}: OpenPGP key URI must be pinned to "
            f"{policy.key_uri}, found {key or 'missing'}"
        )
    else:
        path = key_path_from_uri(policy.key_uri)
        owner = key_owner(path)
        if owner != policy.key_owner:
            errors.append(
                f"{policy.repo_id}: pinned OpenPGP key must exist and be owned by "
                f"{policy.key_owner}, found {owner or 'missing/unowned'}"
            )

    if fields.get("Verify packages") != "true":
        errors.append(
            f"{policy.repo_id}: package signature verification is not enabled"
        )

    if policy.include_packages is not None:
        include = fields.get("Include packages", "")
        if include != policy.include_packages:
            errors.append(
                f"{policy.repo_id}: Include packages must be "
                f"{policy.include_packages}, found {include or 'none'}"
            )

    expected_fp = policy.key_fingerprint.upper()
    if expected_fp not in imported:
        errors.append(
            f"{policy.repo_id}: reviewed OpenPGP fingerprint is not imported: "
            f"{expected_fp}"
        )

    try:
        signer_ids = package_signer_key_ids(policy.package)
    except RuntimeError as exc:
        errors.append(str(exc))
    else:
        expected_key_id = expected_fp[-16:]
        unexpected = sorted(key_id for key_id in signer_ids if key_id != expected_key_id)
        if unexpected:
            errors.append(
                f"{policy.package}: package signer drift; expected key ID "
                f"{expected_key_id}, found {', '.join(unexpected)}"
            )

    return errors


def main() -> int:
    errors = verify_key_packages()

    try:
        imported = imported_key_fingerprints()
    except RuntimeError as exc:
        errors.append(str(exc))
        imported = set()

    for policy in POLICIES:
        policy_errors = check_policy(policy, imported)
        if policy_errors:
            errors.extend(policy_errors)
        else:
            print(
                f"PASS: repository provenance: {policy.repo_id} "
                f"(fingerprint {policy.key_fingerprint}, package {policy.package})"
            )

    if errors:
        for message in errors:
            print(f"FAIL: {message}", file=sys.stderr)
        return 1

    print(
        "PASS: all required external repositories use Fedora-distributed trust anchors, "
        "reviewed fingerprints, and expected package signers"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
