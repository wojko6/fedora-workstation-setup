#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "scripts" / "build-gnome-keyring-i18n-backport.sh"

text = BUILDER.read_text(encoding="utf-8")

required = [
    'EXPECTED_NVR="gnome-keyring-50.0-1.fc44"',
    'EXPECTED_SRPM_FILENAME="${EXPECTED_NVR}.src.rpm"',
    'EXPECTED_SRPM_SHA256="531be762194ec03b714ab00c9ab8c6b18d66df3258772d9ef60168f32b5bde8d"',
    'EXPECTED_SIGNER_FPR="36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6"',
    'dnf download --source --destdir "$download_dir" "$EXPECTED_NVR"',
    'sha256sum "$SRPM"',
    "rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}\\n' \"$SRPM\"",
    'LC_ALL=C rpmkeys --checksig -v "$SRPM"',
    'grep -Fq "$EXPECTED_SIGNER_FPR"',
    '--verify-only',
]

for phrase in required:
    if phrase not in text:
        raise SystemExit(f"FAIL: GNOME Keyring SRPM provenance contract missing: {phrase}")

for forbidden in [
    'dnf download --source "$PACKAGE"',
    '-name "${PACKAGE}-${EXPECTED_VERSION}-*.src.rpm"',
]:
    if forbidden in text:
        raise SystemExit(
            "FAIL: GNOME Keyring builder still accepts a non-exact SRPM source: "
            + forbidden
        )

if text.index('sha256sum "$SRPM"') > text.index('rpm -ivh'):
    raise SystemExit("FAIL: SRPM digest verification occurs after SRPM installation")

if text.index('rpmkeys --checksig -v "$SRPM"') > text.index('rpm -ivh'):
    raise SystemExit("FAIL: SRPM signature verification occurs after SRPM installation")

print("PASS: GNOME Keyring SRPM is pinned to exact NVR and SHA-256")
print("PASS: GNOME Keyring SRPM requires valid Fedora 44 signer fingerprint")
print("PASS: provenance checks occur before SRPM installation or build mutation")
print("=== GNOME KEYRING BACKPORT PROVENANCE TESTS: PASS ===")
