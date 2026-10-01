#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/gnome/managed-system-extensions.tsv"
BUILDER="$ROOT_DIR/scripts/build-ding-v99-managed-tree.sh"
TREE_HELPER="$ROOT_DIR/scripts/extension_tree_integrity.py"

UUID="ding@rastersoft.com"
USER_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
UPDATE_DIR="$HOME/.local/share/gnome-shell/extension-updates/$UUID"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

(( EUID != 0 )) || die "run as the desktop user, not as root"

for cmd in python3 sudo cp mv rm mkdir chown date; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command missing: $cmd"
done

for path in "$MANIFEST" "$BUILDER" "$TREE_HELPER"; do
    [[ -f "$path" ]] || die "required repository file missing: $path"
done

readarray -t row < <(
    python3 - "$MANIFEST" "$UUID" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
uuid = sys.argv[2]

with path.open(encoding="utf-8", newline="") as fh:
    rows = [r for r in csv.DictReader(fh, delimiter="\t") if r.get("uuid") == uuid]

if len(rows) != 1:
    raise SystemExit(f"expected exactly one managed-system row for {uuid}, found {len(rows)}")

r = rows[0]
for key in ("runtime_version", "shell_major", "archive_sha256", "managed_tree_sha256", "location"):
    value = (r.get(key) or "").strip()
    if not value:
        raise SystemExit(f"missing {key} for {uuid}")
    print(value)
PY
)

[[ "${#row[@]}" -eq 5 ]] || die "managed-system manifest parse failed"

VERSION="${row[0]}"
SHELL_MAJOR="${row[1]}"
ARCHIVE_SHA256="${row[2]}"
EXPECTED_TREE_SHA256="${row[3]}"
SYSTEM_DEST="${row[4]}"
SYSTEM_PARENT="$(dirname "$SYSTEM_DEST")"

[[ "$VERSION" == "99" ]] || die "unexpected managed DING version: $VERSION"
[[ "$SHELL_MAJOR" == "50" ]] || die "unexpected managed GNOME major: $SHELL_MAJOR"
[[ "$ARCHIVE_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "invalid archive SHA-256 in manifest"
[[ "$EXPECTED_TREE_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "invalid managed tree SHA-256 in manifest"
[[ "$SYSTEM_DEST" == "/usr/local/share/gnome-shell/extensions/$UUID" ]] ||
    die "unexpected managed DING destination: $SYSTEM_DEST"

BUILD_ROOT="$(mktemp -d)"
SYSTEM_STAGE="$SYSTEM_PARENT/.ding-system-stage.$$"
BACKUP_ROOT="$HOME/.local/state/fedora-workstation-setup/backups"
BACKUP="$BACKUP_ROOT/ding-v99-system-migration-$(date +%Y%m%d-%H%M%S)"
MUTATION_STARTED=0

cleanup() {
    rm -rf "$BUILD_ROOT"
    if (( MUTATION_STARTED == 0 )); then
        sudo rm -rf "$SYSTEM_STAGE" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

rollback() {
    local rc="$1"
    trap - ERR
    echo
    echo "ERROR: migration failed after live mutation began; restoring previous DING state." >&2

    sudo rm -rf "$SYSTEM_STAGE" "$SYSTEM_DEST" >/dev/null 2>&1 || true

    if [[ -d "$BACKUP/system" ]]; then
        sudo mkdir -p "$SYSTEM_PARENT"
        sudo cp -a "$BACKUP/system" "$SYSTEM_DEST"
        sudo chown -R root:root "$SYSTEM_DEST"
    fi

    rm -rf "$USER_DIR" "$UPDATE_DIR"

    if [[ -d "$BACKUP/user" ]]; then
        mkdir -p "$(dirname "$USER_DIR")"
        cp -a "$BACKUP/user" "$USER_DIR"
    fi

    if [[ -d "$BACKUP/update" ]]; then
        mkdir -p "$(dirname "$UPDATE_DIR")"
        cp -a "$BACKUP/update" "$UPDATE_DIR"
    fi

    echo "ROLLBACK=COMPLETED" >&2
    echo "BACKUP=$BACKUP" >&2
    exit "$rc"
}

on_error() {
    local rc="$1"

    if (( MUTATION_STARTED )); then
        rollback "$rc"
    fi

    trap - ERR
    echo "ERROR: pre-mutation validation failed; live DING was not changed." >&2
    exit "$rc"
}
trap 'on_error $?' ERR

echo "=== DING V99 SYSTEM-MANAGED MIGRATION ==="

echo
echo "=== BUILD ACCEPTED TREE ==="
bash "$BUILDER" --output "$BUILD_ROOT/ding"

built_sha="$(python3 "$TREE_HELPER" hash --path "$BUILD_ROOT/ding")"
[[ "$built_sha" == "$EXPECTED_TREE_SHA256" ]] ||
    die "builder tree hash mismatch: expected $EXPECTED_TREE_SHA256, found $built_sha"

echo "PASS: builder tree hash matches managed-system manifest"

if [[ -d "$SYSTEM_DEST" ]] &&
   [[ ! -e "$USER_DIR" ]] &&
   [[ ! -e "$UPDATE_DIR" ]]; then
    current_sha="$(python3 "$TREE_HELPER" hash --path "$SYSTEM_DEST")"
    if [[ "$current_sha" == "$EXPECTED_TREE_SHA256" ]]; then
        owner="$(stat -c '%U:%G' "$SYSTEM_DEST")"
        [[ "$owner" == "root:root" ]] ||
            die "managed DING tree has unexpected owner: $owner"

        echo "PASS: DING v99 is already installed as the accepted system-managed tree"
        echo "MANAGED_TREE_SHA256=$current_sha"
        echo "MIGRATION_REQUIRED=NO"
        exit 0
    fi
fi

echo
echo "=== BACKUP CURRENT STATE ==="
mkdir -p "$BACKUP_ROOT"
chmod 0700 "$BACKUP_ROOT"
mkdir -p "$BACKUP"
chmod 0700 "$BACKUP"

if [[ -d "$USER_DIR" ]]; then
    cp -a "$USER_DIR" "$BACKUP/user"
    echo "BACKUP_USER=YES"
else
    echo "BACKUP_USER=NO"
fi

if [[ -d "$UPDATE_DIR" ]]; then
    cp -a "$UPDATE_DIR" "$BACKUP/update"
    echo "BACKUP_PENDING_UPDATE=YES"
else
    echo "BACKUP_PENDING_UPDATE=NO"
fi

if sudo test -d "$SYSTEM_DEST"; then
    sudo cp -a "$SYSTEM_DEST" "$BACKUP/system"
    sudo chown -R "$(id -u):$(id -g)" "$BACKUP/system"
    echo "BACKUP_SYSTEM=YES"
else
    echo "BACKUP_SYSTEM=NO"
fi

echo
echo "=== PREPARE ROOT-OWNED SYSTEM TREE ==="
sudo mkdir -p "$SYSTEM_PARENT"
sudo rm -rf "$SYSTEM_STAGE"
sudo mkdir -p "$SYSTEM_STAGE"
sudo cp -a "$BUILD_ROOT/ding/." "$SYSTEM_STAGE/"
sudo chown -R root:root "$SYSTEM_STAGE"

stage_sha="$(python3 "$TREE_HELPER" hash --path "$SYSTEM_STAGE")"
[[ "$stage_sha" == "$EXPECTED_TREE_SHA256" ]] ||
    die "root-owned system stage hash mismatch: expected $EXPECTED_TREE_SHA256, found $stage_sha"

echo "PASS: root-owned system stage matches accepted tree hash"

MUTATION_STARTED=1

echo
echo "=== COMMIT MIGRATION ==="
sudo rm -rf "$SYSTEM_DEST"
sudo mv "$SYSTEM_STAGE" "$SYSTEM_DEST"

rm -rf "$USER_DIR"
rm -rf "$UPDATE_DIR"

echo
echo "=== POST-MIGRATION FILESYSTEM ACCEPTANCE ==="
final_sha="$(python3 "$TREE_HELPER" hash --path "$SYSTEM_DEST")"
[[ "$final_sha" == "$EXPECTED_TREE_SHA256" ]] ||
    die "final managed tree hash mismatch: expected $EXPECTED_TREE_SHA256, found $final_sha"

[[ ! -e "$USER_DIR" ]] || die "per-user DING copy still exists"
[[ ! -e "$UPDATE_DIR" ]] || die "pending per-user DING update still exists"

owner="$(stat -c '%U:%G' "$SYSTEM_DEST")"
[[ "$owner" == "root:root" ]] || die "managed DING tree owner mismatch: $owner"

MUTATION_STARTED=0
trap - ERR

echo "PASS: DING v99 installed in system-managed scope"
echo "PASS: per-user DING copy removed"
echo "PASS: pending DING update removed"
echo "MANAGED_TREE_SHA256=$final_sha"
echo "BACKUP=$BACKUP"
echo "MIGRATION_REQUIRED=YES"
echo
echo "A GNOME sign-out/sign-in is required before runtime-path acceptance."
