#!/usr/bin/env bash
set -Eeuo pipefail

OUT="${1:-gnome/extensions-inventory.tsv}"
mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

printf 'uuid\tname\tversion\tshell_versions\turl\tlocation\n' > "$tmp"

# User extensions are scanned first so that, if the same UUID also exists
# system-wide, the user copy (the one GNOME Shell would shadow with) wins.
for base in "$HOME/.local/share/gnome-shell/extensions" /usr/share/gnome-shell/extensions; do
  [[ -d "$base" ]] || continue
  for dir in "$base"/*; do
    [[ -f "$dir/metadata.json" ]] || continue

    # Keep the inventory reproducible across machines/users. Never commit the
    # concrete home directory (for example /home/alice); store it as ~.
    location="$dir"
    if [[ "$location" == "$HOME"/* ]]; then
      location="~${location#$HOME}"
    fi

    python3 - "$dir/metadata.json" "$location" >> "$tmp" <<'PY'
import json, sys
p, location = sys.argv[1:]
with open(p, encoding='utf-8') as f:
    m = json.load(f)

def clean(v):
    if isinstance(v, list):
        return ','.join(map(str, v))
    return '' if v is None else str(v)

vals = [
    m.get('uuid'),
    m.get('name'),
    m.get('version'),
    m.get('shell-version'),
    m.get('url'),
    location,
]
print('\t'.join(clean(v).replace('\t', ' ').replace('\n', ' ') for v in vals))
PY
  done
done

{
  head -n 1 "$tmp"
  # Preserve the first occurrence of each UUID (user extension before system
  # extension), then sort for stable diffs and deterministic reviews.
  tail -n +2 "$tmp" | awk -F '\t' '!seen[$1]++' | LC_ALL=C sort -t $'\t' -k1,1
} > "$OUT"

echo "Saved: $OUT"
