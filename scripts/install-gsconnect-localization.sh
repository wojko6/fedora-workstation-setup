#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="gsconnect@andyholmes.github.io"
DOMAIN="org.gnome.Shell.Extensions.GSConnect"
EXPECTED_VERSION="72"
SOURCE_PO="$ROOT_DIR/localization/gsconnect/pl.po"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
TARGET_MO="$EXT_DIR/locale/pl/LC_MESSAGES/$DOMAIN.mo"
BACKUP_MO="${TARGET_MO}.upstream.bak"
METADATA="$EXT_DIR/metadata.json"
METADATA_BACKUP="${METADATA}.before-localization.bak"

for cmd in msgfmt msgunfmt msgcat python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: $cmd not found" >&2
        exit 1
    fi
done

if [[ ! -d "$EXT_DIR" ]]; then
    echo "SKIP: GSConnect extension not installed: $UUID"
    exit 0
fi

if [[ ! -f "$SOURCE_PO" ]]; then
    echo "FAIL: missing GSConnect Polish overlay: $SOURCE_PO" >&2
    exit 1
fi

if [[ ! -f "$TARGET_MO" ]]; then
    echo "FAIL: upstream GSConnect Polish catalog not found: $TARGET_MO" >&2
    exit 1
fi

if [[ ! -f "$METADATA" ]]; then
    echo "FAIL: GSConnect metadata missing: $METADATA" >&2
    exit 1
fi

# The overlay and gettext-domain workaround were audited against GSConnect v72.
# Refuse to carry them blindly across an extension upgrade; a new version must
# be re-audited first so a stale upstream catalog backup cannot mask changes.
python3 - "$METADATA" "$EXPECTED_VERSION" <<'PY'
import json
import sys

path, expected_version = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

actual_version = str(data.get("version", ""))
if actual_version != expected_version:
    raise SystemExit(
        "FAIL: GSConnect version changed; re-audit localization before applying "
        f"(expected {expected_version}, got {actual_version or '?'})"
    )
PY

msgfmt --check "$SOURCE_PO" -o /dev/null

mkdir -p "$(dirname "$TARGET_MO")"

if [[ ! -f "$BACKUP_MO" ]]; then
    cp -a "$TARGET_MO" "$BACKUP_MO"
    echo "Backup: $BACKUP_MO"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

msgunfmt "$BACKUP_MO" -o "$tmp_dir/upstream.po"

# Overlay is first so its translations win for duplicate msgids while all
# other upstream Polish translations remain intact.
msgcat --use-first \
    "$SOURCE_PO" \
    "$tmp_dir/upstream.po" \
    -o "$tmp_dir/merged.po"

msgfmt --check "$tmp_dir/merged.po" -o "$tmp_dir/merged.mo"

if cmp -s "$tmp_dir/merged.mo" "$TARGET_MO"; then
    echo "PASS: GSConnect Polish completion already installed"
else
    install -m 0644 "$tmp_dir/merged.mo" "$TARGET_MO"

    if cmp -s "$tmp_dir/merged.mo" "$TARGET_MO"; then
        echo "PASS: GSConnect Polish completion installed"
    else
        echo "FAIL: GSConnect localization install verification failed" >&2
        exit 1
    fi
fi

# GNOME Shell 50 uses metadata.json's gettext-domain for translations inside
# the Shell process. GSConnect v72 omits this key while shipping the catalog
# as org.gnome.Shell.Extensions.GSConnect.mo, which leaves Quick Settings
# strings untranslated even though preferences are localized correctly.
if [[ ! -f "$METADATA_BACKUP" ]]; then
    cp -a "$METADATA" "$METADATA_BACKUP"
    echo "Backup: $METADATA_BACKUP"
fi

python3 - "$METADATA" "$DOMAIN" <<'PY'
import json
import sys

path, domain = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

current = data.get("gettext-domain")
if current is not None and current != domain:
    raise SystemExit(
        f"FAIL: unexpected GSConnect gettext-domain: {current!r}"
    )

if current != domain:
    data["gettext-domain"] = domain
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"PASS: GSConnect gettext-domain set to {domain}")
else:
    print(f"PASS: GSConnect gettext-domain already set to {domain}")
PY

echo "INFO: log out and back in after the first gettext-domain change so GNOME Shell reloads extension metadata."
