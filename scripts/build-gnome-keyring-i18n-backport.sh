#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT_DIR/patches/gnome-keyring/fix-gettext-i18n.patch"

PACKAGE="gnome-keyring"
EXPECTED_VERSION="50.0"
EXPECTED_NVR="gnome-keyring-50.0-1.fc44"
EXPECTED_SRPM_FILENAME="${EXPECTED_NVR}.src.rpm"
EXPECTED_SRPM_SHA256="531be762194ec03b714ab00c9ab8c6b18d66df3258772d9ef60168f32b5bde8d"
EXPECTED_SIGNER_FPR="36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6"

WORK_DIR="${GNOME_KEYRING_BACKPORT_WORKDIR:-$HOME/gnome-keyring-i18n-backport}"
RPMBUILD_DIR="$WORK_DIR/rpmbuild"
SPEC_FILE="$RPMBUILD_DIR/SPECS/gnome-keyring.spec"

VERIFY_ONLY=0
case "${1:-}" in
    "")
        ;;
    --verify-only)
        VERIFY_ONLY=1
        ;;
    *)
        echo "Usage: $0 [--verify-only]" >&2
        exit 2
        ;;
esac
if (( $# > 1 )); then
    echo "Usage: $0 [--verify-only]" >&2
    exit 2
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "ERROR: missing patch: $PATCH_FILE" >&2
    exit 1
fi

for cmd in dnf rpm rpmkeys rpmbuild sha256sum grep tr; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    fi
done

mkdir -p "$WORK_DIR"
download_dir="$(mktemp -d -p "$WORK_DIR" .srpm-download.XXXXXX)"
trap 'rm -rf "$download_dir"' EXIT
SRPM="$download_dir/$EXPECTED_SRPM_FILENAME"

echo "==> Downloading exact Fedora source RPM: $EXPECTED_NVR"
dnf download --source --destdir "$download_dir" "$EXPECTED_NVR"

if [[ ! -f "$SRPM" ]]; then
    echo "ERROR: exact Fedora source RPM not found after download: $EXPECTED_SRPM_FILENAME" >&2
    exit 1
fi

# Producer provenance gate: exact artifact digest, package NVR, cryptographic
# signature validity, and the reviewed full Fedora 44 signing-key fingerprint
# must all match before the SRPM is unpacked or any build dependency is changed.
actual_sha="$(sha256sum "$SRPM" | awk '{print $1}')"
if [[ "$actual_sha" != "$EXPECTED_SRPM_SHA256" ]]; then
    echo "ERROR: GNOME Keyring SRPM SHA-256 mismatch" >&2
    echo "Expected: $EXPECTED_SRPM_SHA256" >&2
    echo "Found:    $actual_sha" >&2
    exit 1
fi
echo "PASS: exact GNOME Keyring SRPM SHA-256"

actual_nvr="$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' "$SRPM")"
if [[ "$actual_nvr" != "$EXPECTED_NVR" ]]; then
    echo "ERROR: GNOME Keyring SRPM NVR mismatch" >&2
    echo "Expected: $EXPECTED_NVR" >&2
    echo "Found:    ${actual_nvr:-unknown}" >&2
    exit 1
fi
echo "PASS: exact GNOME Keyring SRPM NVR: $actual_nvr"

if ! signature_output="$(LC_ALL=C rpmkeys --checksig -v "$SRPM" 2>&1)"; then
    printf '%s\n' "$signature_output" >&2
    echo "ERROR: GNOME Keyring SRPM signature verification failed" >&2
    exit 1
fi

signature_output_upper="$(printf '%s\n' "$signature_output" | tr '[:lower:]' '[:upper:]')"
if ! grep -Fq "$EXPECTED_SIGNER_FPR" <<<"$signature_output_upper"; then
    printf '%s\n' "$signature_output" >&2
    echo "ERROR: GNOME Keyring SRPM signer fingerprint mismatch" >&2
    echo "Expected Fedora 44 fingerprint: $EXPECTED_SIGNER_FPR" >&2
    exit 1
fi
echo "PASS: GNOME Keyring SRPM signature valid"
echo "PASS: Fedora 44 signer fingerprint: $EXPECTED_SIGNER_FPR"

if (( VERIFY_ONLY )); then
    echo "PASS: GNOME Keyring SRPM producer provenance verified"
    exit 0
fi

echo "==> Installing verified SRPM into isolated rpmbuild tree"
rm -rf "$RPMBUILD_DIR"
mkdir -p "$RPMBUILD_DIR"

rpm -ivh \
    --define "_topdir $RPMBUILD_DIR" \
    "$SRPM"

if [[ ! -f "$SPEC_FILE" ]]; then
    echo "ERROR: spec file not found: $SPEC_FILE" >&2
    exit 1
fi

SPEC_VERSION="$(awk '/^Version:[[:space:]]*/ {print $2; exit}' "$SPEC_FILE")"

if [[ "$SPEC_VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "ERROR: expected $PACKAGE $EXPECTED_VERSION, got $SPEC_VERSION" >&2
    echo "Refusing to apply a version-specific backport." >&2
    exit 1
fi

echo "==> Installing verified gettext patch"
install -m 0644 \
    "$PATCH_FILE" \
    "$RPMBUILD_DIR/SOURCES/fix-gettext-i18n.patch"

echo "==> Updating Fedora spec"

sed -i \
    's/^Release:[[:space:]]*%autorelease$/Release:        1.i18nfix%{?dist}/' \
    "$SPEC_FILE"

if ! grep -q '^Release:[[:space:]]*1\\.i18nfix%{?dist}$' "$SPEC_FILE"; then
    echo "ERROR: expected Fedora Release line was not updated" >&2
    exit 1
fi

if grep -q '^Patch1:[[:space:]]*fix-gettext-i18n\\.patch$' "$SPEC_FILE"; then
    :
elif grep -q '^Patch:[[:space:]]*78\\.patch$' "$SPEC_FILE"; then
    sed -i \
        '/^Patch:[[:space:]]*78\\.patch$/a Patch1:         fix-gettext-i18n.patch' \
        "$SPEC_FILE"
else
    echo "ERROR: expected Fedora Patch: 78.patch anchor not found" >&2
    exit 1
fi

echo "==> Installing build dependencies"
sudo dnf builddep -y "$SPEC_FILE"

echo "==> Testing patch application"
rpmbuild \
    --define "_topdir $RPMBUILD_DIR" \
    -bp "$SPEC_FILE"

echo "==> Building RPM packages"
rpmbuild \
    --define "_topdir $RPMBUILD_DIR" \
    -bb "$SPEC_FILE"

echo
echo "Backport build completed."
echo "RPM directory:"
echo "  $RPMBUILD_DIR/RPMS"
