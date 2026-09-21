#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class RepoPolicy:
    repo_id: str
    url_field: str
    url_prefix: str
    key_prefix: str
    include_packages: str | None = None


POLICIES = (
    RepoPolicy(
        "rpmfusion-free",
        "Metalink",
        "https://mirrors.rpmfusion.org/metalink?repo=free-fedora-",
        "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-",
    ),
    RepoPolicy(
        "rpmfusion-nonfree",
        "Metalink",
        "https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-",
        "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-",
    ),
    RepoPolicy(
        "brave-browser",
        "Base URL",
        "https://brave-browser-rpm-release.s3.brave.com/",
        "https://brave-browser-rpm-release.s3.brave.com/brave-core.asc",
    ),
    RepoPolicy(
        "copr:copr.fedorainfracloud.org:imput:helium",
        "Base URL",
        "https://download.copr.fedorainfracloud.org/results/imput/helium/",
        "https://download.copr.fedorainfracloud.org/results/imput/helium/pubkey.gpg",
        "helium-bin",
    ),
    RepoPolicy(
        "copr:copr.fedorainfracloud.org:tgerov:vpcs",
        "Base URL",
        "https://download.copr.fedorainfracloud.org/results/tgerov/vpcs/",
        "https://download.copr.fedorainfracloud.org/results/tgerov/vpcs/pubkey.gpg",
        "vpcs",
    ),
)


def repo_info(repo_id: str) -> dict[str, str]:
    proc = subprocess.run(
        ["dnf", "repo", "info", repo_id],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**__import__("os").environ, "LC_ALL": "C"},
        check=False,
    )
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


def check_policy(policy: RepoPolicy) -> list[str]:
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
    if not key.startswith(policy.key_prefix):
        errors.append(
            f"{policy.repo_id}: OpenPGP key outside reviewed source: "
            f"{key or 'missing'}"
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

    return errors


def main() -> int:
    errors: list[str] = []

    for policy in POLICIES:
        policy_errors = check_policy(policy)
        if policy_errors:
            errors.extend(policy_errors)
        else:
            print(f"PASS: repository trust policy: {policy.repo_id}")

    if errors:
        for message in errors:
            print(f"FAIL: {message}", file=sys.stderr)
        return 1

    print("PASS: all required external repositories match reviewed effective trust policy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
