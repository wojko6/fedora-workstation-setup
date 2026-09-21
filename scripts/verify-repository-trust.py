#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
POLICY_FILE = ROOT / "security" / "repository-trust.json"
FINGERPRINT_RE = re.compile(r"^[0-9A-F]{40}$")
KEY_ID_RE = re.compile(r"Key ID ([0-9A-Fa-f]{16,40})")


@dataclass(frozen=True)
class RepoPolicy:
    repo_id: str
    url_field: str
    url_prefix: str
    key_uri: str
    fingerprints: tuple[str, ...]
    package: str
    include_packages: str | None = None
    key_owner: str | None = None


def load_policy() -> tuple[tuple[str, ...], tuple[RepoPolicy, ...]]:
    try:
        data = json.loads(POLICY_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"unable to load repository trust policy: {exc}") from exc

    if data.get("schema_version") != 1:
        raise RuntimeError("repository trust policy has unsupported schema")

    trust_packages_raw = data.get("trust_packages")
    repos_raw = data.get("repositories")
    if not isinstance(trust_packages_raw, list) or not all(
        isinstance(item, str) and item for item in trust_packages_raw
    ):
        raise RuntimeError("trust_packages must be a non-empty string list")
    if not isinstance(repos_raw, list) or not repos_raw:
        raise RuntimeError("repositories must be a non-empty list")

    policies: list[RepoPolicy] = []
    seen: set[str] = set()
    for item in repos_raw:
        if not isinstance(item, dict):
            raise RuntimeError("repository trust policy entry must be an object")

        repo_id = item.get("repo_id")
        fingerprints = item.get("fingerprints")
        key_uri = item.get("key_uri")
        url_field = item.get("url_field")
        url_prefix = item.get("url_prefix")
        package = item.get("package")

        if not isinstance(repo_id, str) or not repo_id or repo_id in seen:
            raise RuntimeError(f"invalid or duplicate repository policy id: {repo_id!r}")
        if not isinstance(fingerprints, list) or not fingerprints:
            raise RuntimeError(f"{repo_id}: fingerprints must be a non-empty list")

        normalized = tuple(str(fpr).upper() for fpr in fingerprints)
        if len(set(normalized)) != len(normalized) or any(
            not FINGERPRINT_RE.fullmatch(fpr) for fpr in normalized
        ):
            raise RuntimeError(f"{repo_id}: invalid or duplicate OpenPGP fingerprint")

        if not isinstance(key_uri, str):
            raise RuntimeError(f"{repo_id}: key_uri is required")
        parsed = urlparse(key_uri)
        if parsed.scheme != "file" or parsed.netloc not in {"", "localhost"}:
            raise RuntimeError(f"{repo_id}: key_uri must be a local file:// URI")

        if not all(
            isinstance(value, str) and value
            for value in (url_field, url_prefix, package)
        ):
            raise RuntimeError(f"{repo_id}: url_field, url_prefix and package are required")

        key_owner = item.get("key_owner")
        if key_owner is not None and (not isinstance(key_owner, str) or not key_owner):
            raise RuntimeError(f"{repo_id}: key_owner must be a non-empty string or null")

        policies.append(
            RepoPolicy(
                repo_id=repo_id,
                url_field=url_field,
                url_prefix=url_prefix,
                key_uri=key_uri,
                fingerprints=normalized,
                package=package,
                include_packages=(
                    str(item["include_packages"])
                    if item.get("include_packages") is not None
                    else None
                ),
                key_owner=key_owner,
            )
        )
        seen.add(repo_id)

    return tuple(trust_packages_raw), tuple(policies)


def policy_by_id(repo_id: str, policies: tuple[RepoPolicy, ...]) -> RepoPolicy:
    for policy in policies:
        if policy.repo_id == repo_id:
            return policy
    raise RuntimeError(f"unknown repository policy id: {repo_id}")


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
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
            f"dnf repo info failed for {repo_id}: {proc.stderr.strip() or 'no diagnostic'}"
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


def key_uri_path(uri: str) -> Path:
    parsed = urlparse(uri)
    if parsed.scheme != "file" or parsed.netloc not in {"", "localhost"}:
        raise RuntimeError(f"unsupported trust-anchor URI: {uri}")
    return Path(unquote(parsed.path))


def primary_fingerprints(path: Path) -> tuple[str, ...]:
    proc = run(["gpg", "--batch", "--with-colons", "--show-keys", str(path)])
    if proc.returncode != 0:
        raise RuntimeError(
            f"gpg failed to read {path}: {proc.stderr.strip() or 'no diagnostic'}"
        )

    fingerprints: list[str] = []
    want_primary = False
    for raw in proc.stdout.splitlines():
        fields = raw.split(":")
        record = fields[0] if fields else ""
        if record == "pub":
            want_primary = True
            continue
        if record == "fpr" and want_primary and len(fields) > 9:
            fingerprints.append(fields[9].upper())
            want_primary = False
        elif record in {"sub", "sec", "ssb"}:
            want_primary = False

    if not fingerprints:
        raise RuntimeError(f"no primary OpenPGP fingerprint found in {path}")
    return tuple(fingerprints)


def check_key_file(policy: RepoPolicy, path: Path) -> list[str]:
    try:
        actual = primary_fingerprints(path)
    except RuntimeError as exc:
        return [f"{policy.repo_id}: {exc}"]

    expected = set(policy.fingerprints)
    found = set(actual)
    if found == expected:
        return []

    details: list[str] = []
    missing = sorted(expected - found)
    unexpected = sorted(found - expected)
    if missing:
        details.append(f"missing={','.join(missing)}")
    if unexpected:
        details.append(f"unexpected={','.join(unexpected)}")
    return [
        f"{policy.repo_id}: trust-anchor fingerprint mismatch: " + "; ".join(details)
    ]


def imported_fingerprints() -> set[str]:
    proc = run(["rpmkeys", "--list"])
    if proc.returncode != 0:
        raise RuntimeError(
            f"rpmkeys --list failed: {proc.stderr.strip() or 'no diagnostic'}"
        )

    fingerprints: set[str] = set()
    for raw in proc.stdout.splitlines():
        first = raw.strip().split(maxsplit=1)[0] if raw.strip() else ""
        candidate = first.upper()
        if FINGERPRINT_RE.fullmatch(candidate):
            fingerprints.add(candidate)
    return fingerprints


def verify_trust_packages(packages: tuple[str, ...]) -> list[str]:
    errors: list[str] = []
    for package in packages:
        installed = run(["rpm", "-q", package])
        if installed.returncode != 0:
            errors.append(f"required Fedora trust-anchor package missing: {package}")
            continue

        verified = run(["rpm", "-V", package])
        if verified.returncode != 0 or verified.stdout.strip():
            detail = verified.stdout.strip() or verified.stderr.strip() or "verification failed"
            errors.append(f"{package}: installed trust-anchor files failed rpm -V: {detail}")
    return errors


def key_owner(path: Path) -> str | None:
    proc = run(["rpm", "-qf", "--qf", "%{NAME}\n", str(path)])
    if proc.returncode != 0:
        return None
    owners = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    return owners[0] if len(owners) == 1 else None


def package_signature_key_ids(package: str) -> tuple[str, ...]:
    proc = run(
        [
            "rpm",
            "-q",
            package,
            "--qf",
            "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n[%{OPENPGP:pgpsig}\n]",
        ]
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"required package is not queryable: {package}: "
            f"{proc.stderr.strip() or proc.stdout.strip() or 'no diagnostic'}"
        )

    key_ids = tuple(match.group(1).upper() for match in KEY_ID_RE.finditer(proc.stdout))
    if not key_ids:
        raise RuntimeError(f"no OpenPGP package signature found for {package}")
    return key_ids


def check_package_signer(policy: RepoPolicy) -> list[str]:
    try:
        key_ids = package_signature_key_ids(policy.package)
    except RuntimeError as exc:
        return [f"{policy.repo_id}: {exc}"]

    allowed = {fingerprint[-16:] for fingerprint in policy.fingerprints}
    unexpected = sorted(
        {key_id[-16:] for key_id in key_ids if key_id[-16:] not in allowed}
    )
    if unexpected:
        return [
            f"{policy.repo_id}: package {policy.package} signed by unexpected key id(s): "
            + ",".join(unexpected)
        ]
    return []


def check_policy(policy: RepoPolicy, imported: set[str]) -> list[str]:
    errors: list[str] = []
    try:
        fields = repo_info(policy.repo_id)
    except RuntimeError as exc:
        return [str(exc)]

    if fields.get("Repo ID") != policy.repo_id:
        errors.append(
            f"{policy.repo_id}: effective Repo ID mismatch: {fields.get('Repo ID', 'missing')}"
        )
    if fields.get("Status") != "enabled":
        errors.append(
            f"{policy.repo_id}: repository is not enabled: {fields.get('Status', 'missing')}"
        )

    url = fields.get(policy.url_field, "")
    if not url.startswith(policy.url_prefix):
        errors.append(
            f"{policy.repo_id}: {policy.url_field} outside reviewed source: {url or 'missing'}"
        )

    key = fields.get("Keys", "")
    if key != policy.key_uri:
        errors.append(
            f"{policy.repo_id}: OpenPGP key URI must be {policy.key_uri}, found {key or 'missing'}"
        )

    if fields.get("Verify packages") != "true":
        errors.append(f"{policy.repo_id}: package signature verification is not enabled")

    if policy.include_packages is not None:
        include = fields.get("Include packages", "")
        if include != policy.include_packages:
            errors.append(
                f"{policy.repo_id}: Include packages must be {policy.include_packages}, "
                f"found {include or 'none'}"
            )

    path = key_uri_path(policy.key_uri)
    errors.extend(check_key_file(policy, path))

    if policy.key_owner is not None:
        owner = key_owner(path)
        if owner != policy.key_owner:
            errors.append(
                f"{policy.repo_id}: trust-anchor file must be owned by {policy.key_owner}, "
                f"found {owner or 'missing/unowned'}"
            )

    missing_imported = sorted(set(policy.fingerprints) - imported)
    if missing_imported:
        errors.append(
            f"{policy.repo_id}: reviewed OpenPGP fingerprint(s) not imported into RPM keyring: "
            + ",".join(missing_imported)
        )

    errors.extend(check_package_signer(policy))
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify external repository trust anchors and package signer identity."
    )
    parser.add_argument(
        "--check-key",
        nargs=2,
        metavar=("REPO_ID", "PATH"),
        help="verify one key file against the pinned fingerprints for REPO_ID",
    )
    return parser.parse_args()


def main() -> int:
    try:
        trust_packages, policies = load_policy()
    except RuntimeError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    args = parse_args()
    if args.check_key:
        repo_id, path_text = args.check_key
        try:
            policy = policy_by_id(repo_id, policies)
        except RuntimeError as exc:
            print(f"FAIL: {exc}", file=sys.stderr)
            return 1
        errors = check_key_file(policy, Path(path_text))
        if errors:
            for message in errors:
                print(f"FAIL: {message}", file=sys.stderr)
            return 1
        print(f"PASS: pinned OpenPGP fingerprint set: {repo_id}")
        return 0

    errors = verify_trust_packages(trust_packages)
    try:
        imported = imported_fingerprints()
    except RuntimeError as exc:
        errors.append(str(exc))
        imported = set()

    for policy in policies:
        policy_errors = check_policy(policy, imported)
        if policy_errors:
            errors.extend(policy_errors)
        else:
            print(f"PASS: repository trust policy: {policy.repo_id}")

    if errors:
        for message in errors:
            print(f"FAIL: {message}", file=sys.stderr)
        return 1

    print(
        "PASS: all required external repositories match pinned trust anchors "
        "and package signers"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
