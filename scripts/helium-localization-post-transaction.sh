#!/usr/bin/env bash
set -Eeuo pipefail

PAK="/opt/helium/locales/pl.pak"
INFO="/opt/helium/locales/pl.pak.info"
PACKAGE="helium-bin"

PATCHER="${HELIUM_PATCHER:-/usr/local/libexec/fedora-workstation-setup/helium_datapack.py}"
OVERLAY="${HELIUM_OVERLAY:-/usr/local/share/fedora-workstation-setup/helium/pl-completion.json}"
STATE_ROOT="${HELIUM_STATE_ROOT:-/var/lib/fedora-workstation-setup/helium}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ "${EUID:-$(id -u)}" -eq 0 ]] || fail "Helium localization transaction helper must run as root"

for cmd in rpm python3 sha256sum install cmp mv mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
done

[[ -f "$PATCHER" ]] || fail "DataPack helper missing: $PATCHER"
[[ -f "$OVERLAY" ]] || fail "localization overlay missing: $OVERLAY"
[[ -f "$PAK" ]] || fail "Helium Polish DataPack missing: $PAK"
[[ -f "$INFO" ]] || fail "Helium Polish DataPack info missing: $INFO"

rpm -q "$PACKAGE" >/dev/null 2>&1 || fail "$PACKAGE is not installed"

version="$(rpm -q --qf '%{VERSION}\n' "$PACKAGE")"
[[ -n "$version" ]] || fail "unable to determine Helium package version"

audited_version="$(
    python3 - "$OVERLAY" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(json.load(fh)["audited_build"]["version"])
PY
)"

expected_baseline_sha="$(
    python3 - "$OVERLAY" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(json.load(fh)["audited_build"]["upstream_pl_pak_sha256"])
PY
)"

state_dir="$STATE_ROOT/$version"
backup_pak="$state_dir/pl.pak.upstream"
backup_info="$state_dir/pl.pak.info.upstream"

mkdir -p "$state_dir"
chmod 0755 "$STATE_ROOT" "$state_dir" 2>/dev/null || true

verify_output="$(LC_ALL=C rpm -V "$PACKAGE" 2>&1 || true)"
pak_is_pristine=1
info_is_pristine=1

if grep -Fq "$PAK" <<<"$verify_output"; then
    pak_is_pristine=0
fi
if grep -Fq "$INFO" <<<"$verify_output"; then
    info_is_pristine=0
fi

if [[ ! -f "$backup_pak" || ! -f "$backup_info" ]]; then
    (( pak_is_pristine == 1 )) || fail "cannot create upstream backup: live $PAK is already modified"
    (( info_is_pristine == 1 )) || fail "cannot create upstream backup: live $INFO is already modified"

    if [[ "$version" == "$audited_version" ]]; then
        live_sha="$(sha256sum "$PAK" | awk '{print $1}')"
        [[ "$live_sha" == "$expected_baseline_sha" ]] ||
            fail "audited Helium $version Polish DataPack fingerprint differs: $live_sha"
    fi

    install -m 0644 "$PAK" "$backup_pak"
    install -m 0644 "$INFO" "$backup_info"
    echo "Backup: $backup_pak"
    echo "Backup: $backup_info"
else
    if (( pak_is_pristine == 1 )); then
        cmp -s "$PAK" "$backup_pak" ||
            fail "same-version producer DataPack changed; refusing to reuse old upstream backup"
    fi
    if (( info_is_pristine == 1 )); then
        cmp -s "$INFO" "$backup_info" ||
            fail "same-version producer DataPack info changed; refusing to reuse old upstream backup"
    fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
output="$tmpdir/pl.pak"

apply_args=(
    apply
    --pak "$backup_pak"
    --info "$backup_info"
    --overlay "$OVERLAY"
    --output "$output"
)

if [[ "$version" == "$audited_version" ]]; then
    apply_args+=(--strict --enforce-resource-ids)
fi

python3 "$PATCHER" "${apply_args[@]}"

if cmp -s "$output" "$PAK"; then
    echo "PASS: Helium $version Polish completion already installed"
else
    staged="$PAK.fedora-workstation-setup.new"
    install -m 0644 "$output" "$staged"
    mv -f "$staged" "$PAK"
    if command -v restorecon >/dev/null 2>&1; then
        restorecon -F "$PAK" >/dev/null 2>&1 || true
    fi
    echo "PASS: Helium $version Polish completion installed atomically"
fi

if [[ "$version" == "$audited_version" ]]; then
    python3 "$PATCHER" verify         --pak "$PAK"         --info "$INFO"         --overlay "$OVERLAY"         --enforce-resource-ids
else
    echo "WARN: Helium version $version is newer/different than audited $audited_version."
    echo "WARN: Only entries still matching the audited English source were patched; re-audit is required."
fi
