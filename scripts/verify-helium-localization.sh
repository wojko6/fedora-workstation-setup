#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGE="helium-bin"
EXPECTED_VERSION="0.17.2.1"
EXPECTED_UPSTREAM_PAK_SHA="93b0489811a30c4005294b192b6cadbd4089ab29da9e167fa40f48a2320940a6"
EXPECTED_ENTRIES=36

PAK="/opt/helium/locales/pl.pak"
INFO="/opt/helium/locales/pl.pak.info"

PATCHER_SRC="$ROOT_DIR/scripts/helium_datapack.py"
HELPER_SRC="$ROOT_DIR/scripts/helium-localization-post-transaction.sh"
OVERLAY_SRC="$ROOT_DIR/localization/helium/v0.17.2.1-pl-completion.json"
ACTION_SRC="$ROOT_DIR/system/dnf5/actions.d/90-helium-localization.actions"

PATCHER_DST="/usr/local/libexec/fedora-workstation-setup/helium_datapack.py"
HELPER_DST="/usr/local/libexec/fedora-workstation-setup/helium-localization-post-transaction"
OVERLAY_DST="/usr/local/share/fedora-workstation-setup/helium/pl-completion.json"
ACTION_DST="/etc/dnf/libdnf5-plugins/actions.d/90-helium-localization.actions"

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "SKIP: Helium RPM is not installed"
    exit 0
fi

for cmd in rpm python3 sha256sum cmp mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    }
done

version="$(rpm -q --qf '%{VERSION}\n' "$PACKAGE")"
if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Helium version drift: expected $EXPECTED_VERSION, found ${version:-unknown}" >&2
    echo "FAIL: the post-transaction helper may safely preserve still-matching entries, but full localization acceptance requires re-audit" >&2
    exit 1
fi

for path in     "$PAK" "$INFO"     "$PATCHER_SRC" "$HELPER_SRC" "$OVERLAY_SRC" "$ACTION_SRC"     "$PATCHER_DST" "$HELPER_DST" "$OVERLAY_DST" "$ACTION_DST"; do
    [[ -f "$path" ]] || {
        echo "FAIL: required Helium localization file missing: $path" >&2
        exit 1
    }
done

rpm -q libdnf5-plugin-actions >/dev/null 2>&1 || {
    echo "FAIL: libdnf5-plugin-actions is not installed" >&2
    exit 1
}

if [[ -f /etc/dnf/libdnf5-plugins/actions.conf ]] &&
   grep -Eiq '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*(0|false|no)[[:space:]]*$'        /etc/dnf/libdnf5-plugins/actions.conf; then
    echo "FAIL: DNF5 actions plugin is explicitly disabled" >&2
    exit 1
fi

cmp -s "$PATCHER_SRC" "$PATCHER_DST" || {
    echo "FAIL: installed Helium DataPack helper differs from repository" >&2
    exit 1
}
cmp -s "$HELPER_SRC" "$HELPER_DST" || {
    echo "FAIL: installed Helium transaction helper differs from repository" >&2
    exit 1
}
cmp -s "$OVERLAY_SRC" "$OVERLAY_DST" || {
    echo "FAIL: installed Helium overlay differs from repository" >&2
    exit 1
}
cmp -s "$ACTION_SRC" "$ACTION_DST" || {
    echo "FAIL: installed Helium DNF5 action differs from repository" >&2
    exit 1
}

python3 "$PATCHER_SRC" self-test
python3 "$PATCHER_SRC" validate-overlay --overlay "$OVERLAY_SRC"

entry_count="$(
    python3 - "$OVERLAY_SRC" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(len(json.load(fh)["translations"]))
PY
)"
if [[ "$entry_count" != "$EXPECTED_ENTRIES" ]]; then
    echo "FAIL: Helium overlay entry count: expected $EXPECTED_ENTRIES, found $entry_count" >&2
    exit 1
fi

state_dir="/var/lib/fedora-workstation-setup/helium/$version"
backup_pak="$state_dir/pl.pak.upstream"
backup_info="$state_dir/pl.pak.info.upstream"

for path in "$backup_pak" "$backup_info"; do
    [[ -f "$path" ]] || {
        echo "FAIL: Helium upstream backup missing: $path" >&2
        exit 1
    }
done

backup_sha="$(sha256sum "$backup_pak" | awk '{print $1}')"
if [[ "$backup_sha" != "$EXPECTED_UPSTREAM_PAK_SHA" ]]; then
    echo "FAIL: Helium pristine Polish DataPack backup fingerprint differs: $backup_sha" >&2
    exit 1
fi

cmp -s "$INFO" "$backup_info" || {
    echo "FAIL: live Helium pl.pak.info differs from the audited producer backup" >&2
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 "$PATCHER_SRC" apply     --pak "$backup_pak"     --info "$backup_info"     --overlay "$OVERLAY_SRC"     --output "$tmpdir/pl.pak"     --strict     --enforce-resource-ids

cmp -s "$tmpdir/pl.pak" "$PAK" || {
    echo "FAIL: live Helium Polish DataPack differs from reconstructed repository completion" >&2
    exit 1
}

python3 "$PATCHER_SRC" verify     --pak "$PAK"     --info "$INFO"     --overlay "$OVERLAY_SRC"     --enforce-resource-ids

echo "PASS: Helium $EXPECTED_VERSION Polish localization matches repository completion ($EXPECTED_ENTRIES entries)"
echo "PASS: DNF5 post-transaction persistence is installed for helium-bin updates"
