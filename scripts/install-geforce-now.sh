#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE="GeForceNOW"
APP="com.nvidia.geforcenow"
BRANCH="master"

FLATPAKREPO_URL="https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo"
EXPECTED_REPO_URL="https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow_repo"

for cmd in flatpak awk grep; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command unavailable: $cmd" >&2
        exit 1
    }
done

remote_exists=0

if flatpak remotes --user --columns=name 2>/dev/null \
    | grep -Fxq "$REMOTE"; then
    remote_exists=1
fi

if (( ! remote_exists )); then
    flatpak remote-add \
        --user \
        --if-not-exists \
        "$REMOTE" \
        "$FLATPAKREPO_URL"

    echo "Added official NVIDIA GeForce NOW Flatpak remote"
fi

remote_url="$(
    flatpak remotes --user --columns=name,url 2>/dev/null \
    | awk -v remote="$REMOTE" '$1 == remote { print $2; exit }'
)"

normalized_url="${remote_url%/}"

case "$normalized_url" in
    "$EXPECTED_REPO_URL"|"${FLATPAKREPO_URL%/}")
        ;;
    *)
        echo "FAIL: unexpected GeForce NOW remote URL: ${remote_url:-missing}" >&2
        exit 1
        ;;
esac

flatpak install \
    --user \
    -y \
    "$REMOTE" \
    "${APP}//${BRANCH}"

origin="$(flatpak info --user --show-origin "$APP")"
ref="$(flatpak info --user --show-ref "$APP")"

[[ "$origin" == "$REMOTE" ]] || {
    echo "FAIL: GeForce NOW origin: expected $REMOTE, found $origin" >&2
    exit 1
}

[[ "$ref" == "app/$APP/"*"/$BRANCH" ]] || {
    echo "FAIL: unexpected GeForce NOW ref: $ref" >&2
    exit 1
}

EXPORT="$HOME/.local/share/flatpak/exports/share/applications/$APP.desktop"

[[ -e "$EXPORT" ]] || {
    echo "FAIL: GeForce NOW desktop export missing: $EXPORT" >&2
    exit 1
}

echo "PASS: GeForce NOW official user Flatpak installed"
echo "REF=$ref"
echo "ORIGIN=$origin"
