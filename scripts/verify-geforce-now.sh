#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE="GeForceNOW"
APP="com.nvidia.geforcenow"
BRANCH="master"

EXPECTED_REPO_URL="https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow_repo"

EXPORT="$HOME/.local/share/flatpak/exports/share/applications/$APP.desktop"

command -v flatpak >/dev/null 2>&1 || {
    echo "FAIL: flatpak unavailable" >&2
    exit 1
}

flatpak info --user "$APP" >/dev/null 2>&1 || {
    echo "FAIL: GeForce NOW user Flatpak not installed" >&2
    exit 1
}

origin="$(flatpak info --user --show-origin "$APP")"
ref="$(flatpak info --user --show-ref "$APP")"
commit="$(flatpak info --user --show-commit "$APP")"

[[ "$origin" == "$REMOTE" ]] || {
    echo "FAIL: GeForce NOW origin: expected $REMOTE, found $origin" >&2
    exit 1
}

[[ "$ref" == "app/$APP/"*"/$BRANCH" ]] || {
    echo "FAIL: GeForce NOW ref drift: $ref" >&2
    exit 1
}

remote_url="$(
    flatpak remotes --user --columns=name,url 2>/dev/null \
    | awk -v remote="$REMOTE" '$1 == remote { print $2; exit }'
)"

normalized_url="${remote_url%/}"

[[ "$normalized_url" == "$EXPECTED_REPO_URL" ]] || {
    echo "FAIL: GeForce NOW remote URL drift: ${remote_url:-missing}" >&2
    exit 1
}

[[ -e "$EXPORT" ]] || {
    echo "FAIL: GeForce NOW desktop export missing" >&2
    exit 1
}

grep -Fq 'Type=Application' "$EXPORT" || {
    echo "FAIL: invalid GeForce NOW desktop export" >&2
    exit 1
}

grep -Fq 'com.nvidia.geforcenow' "$EXPORT" || {
    echo "FAIL: GeForce NOW desktop export does not reference expected app ID" >&2
    exit 1
}

echo "PASS: GeForce NOW user Flatpak matches repository policy"
echo "REF=$ref"
echo "ORIGIN=$origin"
echo "COMMIT=$commit"
