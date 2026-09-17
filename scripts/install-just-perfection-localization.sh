#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UUID="just-perfection-desktop@just-perfection"
DOMAIN="just-perfection"
EXPECTED_VERSION="37"
SOURCE_PO="$ROOT_DIR/localization/just-perfection/pl.po"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
METADATA="$EXT_DIR/metadata.json"
LOCALE_DIR="$EXT_DIR/locale/pl/LC_MESSAGES"
TARGET_MO="$LOCALE_DIR/$DOMAIN.mo"

command -v python3 >/dev/null 2>&1 || {
  echo "FAIL: python3 is required" >&2
  exit 1
}
command -v msgfmt >/dev/null 2>&1 || {
  echo "FAIL: msgfmt is required (install gettext)" >&2
  exit 1
}

if [[ ! -d "$EXT_DIR" ]]; then
  echo "SKIP: Just Perfection is not installed: $UUID"
  exit 0
fi

[[ -f "$METADATA" ]] || {
  echo "FAIL: missing Just Perfection metadata: $METADATA" >&2
  exit 1
}
[[ -f "$SOURCE_PO" ]] || {
  echo "FAIL: missing Polish translation source: $SOURCE_PO" >&2
  exit 1
}

read -r version domain < <(
  python3 - "$METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("version", ""), data.get("gettext-domain", ""))
PY
)

if [[ "$version" != "$EXPECTED_VERSION" ]]; then
  echo "FAIL: Just Perfection version changed: expected $EXPECTED_VERSION, found ${version:-unknown}. Re-audit Polish localization before applying it." >&2
  exit 1
fi

if [[ "$domain" != "$DOMAIN" ]]; then
  echo "FAIL: unexpected Just Perfection gettext domain: expected $DOMAIN, found ${domain:-missing}" >&2
  exit 1
fi

msgfmt --check "$SOURCE_PO" -o /dev/null

mkdir -p "$LOCALE_DIR"
tmp_mo="$(mktemp)"
trap 'rm -f "$tmp_mo"' EXIT
msgfmt "$SOURCE_PO" -o "$tmp_mo"

if [[ -f "$TARGET_MO" ]] && cmp -s "$tmp_mo" "$TARGET_MO"; then
  echo "PASS: Just Perfection v37 Polish localization already installed"
  exit 0
fi

if [[ -f "$TARGET_MO" ]]; then
  backup="${TARGET_MO}.upstream-v37.bak"
  if [[ ! -f "$backup" ]]; then
    cp -a "$TARGET_MO" "$backup"
    echo "Backup: $backup"
  fi
fi

install -m 0644 "$tmp_mo" "$TARGET_MO"
cmp -s "$tmp_mo" "$TARGET_MO" || {
  echo "FAIL: installed Just Perfection translation differs from repository build" >&2
  exit 1
}

echo "PASS: Just Perfection v37 Polish localization installed"
echo "Log out and back in before visually validating the translated preferences."
