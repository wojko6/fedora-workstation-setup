#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT_DIR/patches/gnome-keyring/fix-gettext-i18n.patch"

PACKAGE="gnome-keyring"
EXPECTED_VERSION="50.0"

WORK_DIR="${GNOME_KEYRING_BACKPORT_WORKDIR:-$HOME/gnome-keyring-i18n-backport}"
RPMBUILD_DIR="$WORK_DIR/rpmbuild"
SPEC_FILE="$RPMBUILD_DIR/SPECS/gnome-keyring.spec"

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "ERROR: missing patch: $PATCH_FILE" >&2
    exit 1
fi

for cmd in dnf rpm rpmbuild; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    fi
done

mkdir -p "$WORK_DIR"

echo "==> Downloading Fedora source RPM for $PACKAGE"
(
    cd "$WORK_DIR"
    dnf download --source "$PACKAGE"
)

SRPM="$(
    find "$WORK_DIR" -maxdepth 1 -type f \
        -name "${PACKAGE}-${EXPECTED_VERSION}-*.src.rpm" \
        -printf '%T@ %p\n' |
    sort -nr |
    head -n1 |
    cut -d' ' -f2-
)"

if [[ -z "${SRPM:-}" || ! -f "$SRPM" ]]; then
    echo "ERROR: Fedora $PACKAGE $EXPECTED_VERSION source RPM not found" >&2
    exit 1
fi

echo "==> Installing SRPM into isolated rpmbuild tree"
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

if ! grep -q '^Release:[[:space:]]*1\.i18nfix%{?dist}$' "$SPEC_FILE"; then
    echo "ERROR: expected Fedora Release line was not updated" >&2
    exit 1
fi

if grep -q '^Patch1:[[:space:]]*fix-gettext-i18n\.patch$' "$SPEC_FILE"; then
    :
elif grep -q '^Patch:[[:space:]]*78\.patch$' "$SPEC_FILE"; then
    sed -i \
        '/^Patch:[[:space:]]*78\.patch$/a Patch1:         fix-gettext-i18n.patch' \
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
